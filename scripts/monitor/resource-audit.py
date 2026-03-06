#!/usr/bin/env python3
"""
Resource audit script: queries Prometheus for 7d container resource stats,
compares against docker-compose limits, and recommends tuning + overbooking strategy.
"""
import json
import re
import sys
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from typing import Optional

# ── Config ──────────────────────────────────────────────────────────────────
PROMETHEUS_URL = "http://localhost:9090"
COMPOSE_FILE = "/home/daniel/potatostack/docker-compose.yml"
RANGE = "7d"
# Headroom multipliers over observed max before capping limit
CPU_HEADROOM = 1.3   # 30% above p99 max
MEM_HEADROOM = 1.25  # 25% above observed max
# Overbooking ratios (sum-of-limits / actual-capacity)
HOST_CPUS = 4        # Intel N150 has 4 cores (4C/4T, no hyperthreading)
HOST_MEM_GB = 16
OVERBOOK_CPU_RATIO = 2.5   # safe for mixed idle workload
OVERBOOK_MEM_RATIO = 1.15  # memory overbooking is risky; keep conservative


def prom_query(query: str) -> list[dict]:
    url = f"{PROMETHEUS_URL}/api/v1/query"
    data = urllib.parse.urlencode({"query": query}).encode()
    req = urllib.request.Request(url, data=data, method="POST")
    with urllib.request.urlopen(req, timeout=30) as resp:
        d = json.load(resp)
    return d.get("data", {}).get("result", [])


def build_stats(metric: str, agg: str) -> dict[str, float]:
    """Return {container_name: value} for a given aggregation over RANGE."""
    results = prom_query(f'{agg}({metric}[{RANGE}])')
    out = {}
    for r in results:
        name = r["metric"].get("name", "")
        if name:
            try:
                out[name] = float(r["value"][1])
            except (ValueError, IndexError):
                pass
    return out


def build_cpu_stats() -> dict[str, dict]:
    """CPU in cores (rate of usage_seconds_total)."""
    # max by (name) aggregates across all historical container IDs for the same name
    base = "rate(container_cpu_usage_seconds_total[5m])"
    q_max = f"max by (name) (max_over_time(({base})[{RANGE}:5m]))"
    q_avg = f"max by (name) (avg_over_time(({base})[{RANGE}:5m]))"
    q_min = f"min by (name) (min_over_time(({base})[{RANGE}:5m]))"

    def fetch(q):
        results = prom_query(q)
        out = {}
        for r in results:
            name = r["metric"].get("name", "")
            if name:
                try:
                    out[name] = float(r["value"][1])
                except (ValueError, IndexError):
                    pass
        return out

    maxv = fetch(q_max)
    avgv = fetch(q_avg)
    minv = fetch(q_min)

    all_names = set(maxv) | set(avgv) | set(minv)
    out = {}
    for n in all_names:
        out[n] = {
            "max": maxv.get(n, 0),
            "avg": avgv.get(n, 0),
            "min": minv.get(n, 0),
        }
    return out


def build_mem_stats() -> dict[str, dict]:
    """Memory in bytes using usage_bytes (RSS + cache, matches docker stats)."""
    metric = "container_memory_usage_bytes"
    # max by (name) collapses all historical container IDs for same-named containers
    q_max = f"max by (name) (max_over_time({metric}[{RANGE}]))"
    q_avg = f"max by (name) (avg_over_time({metric}[{RANGE}]))"
    q_min = f"min by (name) (min_over_time({metric}[{RANGE}]))"

    def fetch(q):
        results = prom_query(q)
        out = {}
        for r in results:
            name = r["metric"].get("name", "")
            if name:
                try:
                    out[name] = float(r["value"][1])
                except (ValueError, IndexError):
                    pass
        return out

    maxv = fetch(q_max)
    avgv = fetch(q_avg)
    minv = fetch(q_min)

    all_names = set(maxv) | set(avgv) | set(minv)
    out = {}
    for n in all_names:
        out[n] = {
            "max": maxv.get(n, 0),
            "avg": avgv.get(n, 0),
            "min": minv.get(n, 0),
        }
    return out


@dataclass
class ServiceLimits:
    cpu_limit: Optional[float] = None
    cpu_reserve: Optional[float] = None
    mem_limit_bytes: Optional[int] = None
    mem_reserve_bytes: Optional[int] = None


def parse_mem(s: str) -> int:
    """Parse '256M', '1536M', '2G' etc to bytes."""
    s = s.strip().upper()
    m = re.match(r"^([0-9.]+)\s*([KMGT]?)B?$", s)
    if not m:
        return 0
    val, unit = float(m.group(1)), m.group(2)
    mult = {"K": 1024, "M": 1024**2, "G": 1024**3, "T": 1024**4}.get(unit, 1)
    return int(val * mult)


def parse_compose_limits(compose_file: str) -> dict[str, ServiceLimits]:
    """
    Parse docker-compose.yml for service resource limits.
    Simple line-by-line parser (avoids yaml dep).
    """
    limits: dict[str, ServiceLimits] = {}
    with open(compose_file) as f:
        lines = f.readlines()

    current_service = None
    in_services = False
    in_deploy = False
    in_resources = False
    in_limits = False
    in_reservations = False

    for line in lines:
        stripped = line.rstrip()
        if not stripped or stripped.lstrip().startswith("#"):
            continue

        indent = len(line) - len(line.lstrip())
        content = line.strip()

        if stripped == "services:":
            in_services = True
            continue

        if not in_services:
            continue

        # Top-level non-services: section exits services block
        if indent == 0:
            if content != "services:":
                in_services = False
            continue

        # Service names at indent 2
        if indent == 2 and content.endswith(":") and not content.startswith("-"):
            current_service = content[:-1]
            limits.setdefault(current_service, ServiceLimits())
            in_deploy = in_resources = in_limits = in_reservations = False
            continue

        if current_service is None:
            continue

        # deploy: at indent 4
        if indent == 4:
            in_deploy = (content == "deploy:")
            if not in_deploy:
                in_resources = in_limits = in_reservations = False
            continue

        if not in_deploy:
            continue

        # resources: at indent 6
        if indent == 6:
            in_resources = content.startswith("resources")
            if not in_resources:
                in_limits = in_reservations = False
            continue

        if not in_resources:
            continue

        # limits:/reservations: at indent 8
        if indent == 8:
            if content == "limits:":
                in_limits, in_reservations = True, False
            elif content == "reservations:":
                in_limits, in_reservations = False, True
            continue

        # cpus:/memory: at indent 10
        if indent == 10:
            if content.startswith("cpus:"):
                val = content.split(":", 1)[1].strip().strip('"')
                try:
                    v = float(val)
                    if in_limits:
                        limits[current_service].cpu_limit = v
                    elif in_reservations:
                        limits[current_service].cpu_reserve = v
                except ValueError:
                    pass
            elif content.startswith("memory:"):
                val = content.split(":", 1)[1].strip()
                v = parse_mem(val)
                if v:
                    if in_limits:
                        limits[current_service].mem_limit_bytes = v
                    elif in_reservations:
                        limits[current_service].mem_reserve_bytes = v

    return limits


def fmt_cpu(cores: float) -> str:
    return f"{cores:.3f}c"


def fmt_mem(b: float) -> str:
    if b >= 1024**3:
        return f"{b/1024**3:.2f}G"
    if b >= 1024**2:
        return f"{b/1024**2:.1f}M"
    if b >= 1024:
        return f"{b/1024:.1f}K"
    return f"{b:.0f}B"


def recommend_cpu_limit(max_cores: float) -> float:
    """Recommend a CPU limit based on observed max."""
    raw = max_cores * CPU_HEADROOM
    # Round up to nearest 0.25
    return round(max(0.05, round(raw / 0.25) * 0.25), 2)


def recommend_mem_limit(max_bytes: float) -> int:
    """Recommend memory limit based on observed max."""
    raw = max_bytes * MEM_HEADROOM
    # Round up to nearest 32M
    mb = max(16, int(raw / (32 * 1024**2) + 0.999) * 32)
    return mb * 1024 * 1024


def main():
    print("=" * 80)
    print("POTATOSTACK RESOURCE AUDIT — 7-day window")
    print("=" * 80)
    print()

    print("Fetching CPU stats from Prometheus...", flush=True)
    cpu = build_cpu_stats()
    print(f"  Got CPU data for {len(cpu)} containers")

    print("Fetching memory stats from Prometheus...", flush=True)
    mem = build_mem_stats()
    print(f"  Got memory data for {len(mem)} containers")

    print("Parsing docker-compose limits...", flush=True)
    compose_limits = parse_compose_limits(COMPOSE_FILE)
    print(f"  Parsed limits for {len(compose_limits)} services")
    print()

    all_containers = sorted(set(cpu) | set(mem))

    # ── Per-service table ───────────────────────────────────────────────────
    print(f"{'SERVICE':<35} {'CPU_AVG':>8} {'CPU_MAX':>8} {'MEM_AVG':>9} {'MEM_MAX':>9} "
          f"{'LIM_CPU':>8} {'LIM_MEM':>8} {'REC_CPU':>8} {'REC_MEM':>8} {'ACTION'}")
    print("-" * 135)

    recommendations = []

    for name in all_containers:
        c = cpu.get(name, {})
        m = mem.get(name, {})
        lim = compose_limits.get(name, ServiceLimits())

        c_avg = c.get("avg", 0)
        c_max = c.get("max", 0)
        m_avg = m.get("avg", 0)
        m_max = m.get("max", 0)

        rec_cpu = recommend_cpu_limit(c_max) if c_max > 0 else None
        rec_mem_bytes = recommend_mem_limit(m_max) if m_max > 0 else None

        # Determine actions
        actions = []

        if lim.cpu_limit and rec_cpu:
            ratio = lim.cpu_limit / rec_cpu
            if ratio > 2.0:
                actions.append(f"CPU↓ {fmt_cpu(lim.cpu_limit)}→{fmt_cpu(rec_cpu)}")
            elif ratio < 0.85:
                actions.append(f"CPU↑ {fmt_cpu(lim.cpu_limit)}→{fmt_cpu(rec_cpu)}")
        elif not lim.cpu_limit and c_max > 0:
            actions.append(f"SET_CPU {fmt_cpu(rec_cpu)}")

        if lim.mem_limit_bytes and rec_mem_bytes:
            ratio = lim.mem_limit_bytes / rec_mem_bytes
            if ratio > 2.5:
                actions.append(f"MEM↓ {fmt_mem(lim.mem_limit_bytes)}→{fmt_mem(rec_mem_bytes)}")
            elif ratio < 0.9:
                actions.append(f"MEM↑ {fmt_mem(lim.mem_limit_bytes)}→{fmt_mem(rec_mem_bytes)}")
        elif not lim.mem_limit_bytes and m_max > 0:
            actions.append(f"SET_MEM {fmt_mem(rec_mem_bytes)}")

        action_str = ", ".join(actions) if actions else "OK"

        print(
            f"{name:<35} "
            f"{fmt_cpu(c_avg):>8} {fmt_cpu(c_max):>8} "
            f"{fmt_mem(m_avg):>9} {fmt_mem(m_max):>9} "
            f"{fmt_cpu(lim.cpu_limit) if lim.cpu_limit else 'none':>8} "
            f"{fmt_mem(lim.mem_limit_bytes) if lim.mem_limit_bytes else 'none':>8} "
            f"{fmt_cpu(rec_cpu) if rec_cpu else 'n/a':>8} "
            f"{fmt_mem(rec_mem_bytes) if rec_mem_bytes else 'n/a':>8} "
            f"  {action_str}"
        )

        if actions:
            recommendations.append((name, actions, lim, rec_cpu, rec_mem_bytes, c_max, m_max))

    # ── Overbooking analysis ────────────────────────────────────────────────
    print()
    print("=" * 80)
    print("OVERBOOKING ANALYSIS")
    print("=" * 80)

    total_cpu_limit = sum(
        lim.cpu_limit for lim in compose_limits.values() if lim.cpu_limit
    )
    total_cpu_reserve = sum(
        lim.cpu_reserve for lim in compose_limits.values() if lim.cpu_reserve
    )
    total_mem_limit_gb = sum(
        lim.mem_limit_bytes for lim in compose_limits.values() if lim.mem_limit_bytes
    ) / 1024**3
    total_mem_reserve_gb = sum(
        lim.mem_reserve_bytes for lim in compose_limits.values() if lim.mem_reserve_bytes
    ) / 1024**3

    total_cpu_used_avg = sum(c.get("avg", 0) for c in cpu.values())
    total_cpu_used_max = sum(c.get("max", 0) for c in cpu.values())
    total_mem_used_avg = sum(m.get("avg", 0) for m in mem.values()) / 1024**3
    total_mem_used_max = sum(m.get("max", 0) for m in mem.values()) / 1024**3

    print(f"\nHost capacity:     {HOST_CPUS} CPUs   {HOST_MEM_GB}GB RAM")
    print(f"\nCurrent limits:    {total_cpu_limit:.1f} CPU  {total_mem_limit_gb:.1f}GB")
    print(f"Current reserves:  {total_cpu_reserve:.1f} CPU  {total_mem_reserve_gb:.1f}GB")
    print(f"\n7d usage avg:      {total_cpu_used_avg:.2f} CPU  {total_mem_used_avg:.2f}GB")
    print(f"7d usage max:      {total_cpu_used_max:.2f} CPU  {total_mem_used_max:.2f}GB")
    print()
    print(f"CPU limit/host:    {total_cpu_limit/HOST_CPUS:.1f}x  (safe overbook threshold: {OVERBOOK_CPU_RATIO}x)")
    print(f"MEM limit/host:    {total_mem_limit_gb/HOST_MEM_GB:.2f}x  (safe overbook threshold: {OVERBOOK_MEM_RATIO}x)")
    print(f"CPU avg util:      {total_cpu_used_avg/HOST_CPUS*100:.1f}%")
    print(f"MEM avg util:      {total_mem_used_avg/HOST_MEM_GB*100:.1f}%")

    # ── Overbooking recommendation ──────────────────────────────────────────
    print()
    print("OVERBOOKING STRATEGY")
    print("-" * 60)

    cpu_overbook_current = total_cpu_limit / HOST_CPUS
    mem_overbook_current = total_mem_limit_gb / HOST_MEM_GB

    print(f"\n[CPU] Currently {cpu_overbook_current:.1f}x overbooked (limits/{HOST_CPUS} CPUs)")
    if cpu_overbook_current < OVERBOOK_CPU_RATIO:
        headroom = OVERBOOK_CPU_RATIO * HOST_CPUS - total_cpu_limit
        print(f"  → SAFE: {headroom:.1f} CPU headroom before reaching {OVERBOOK_CPU_RATIO}x")
        print(f"  → Can allocate ~{headroom:.1f} more CPU limit budget")
        print(f"  → CPU avg utilization is only {total_cpu_used_avg/HOST_CPUS*100:.1f}% — "
              f"overbooking is rational here")
    elif cpu_overbook_current > OVERBOOK_CPU_RATIO:
        excess = total_cpu_limit - OVERBOOK_CPU_RATIO * HOST_CPUS
        print(f"  → OVERBOOKED: {excess:.1f} CPUs over safe threshold")
        print(f"  → Reduce limits on idle services (see recommendations above)")
    else:
        print(f"  → AT THRESHOLD")

    print(f"\n[MEM] Currently {mem_overbook_current:.2f}x overbooked (limits/{HOST_MEM_GB}GB)")
    if mem_overbook_current < OVERBOOK_MEM_RATIO:
        headroom_gb = OVERBOOK_MEM_RATIO * HOST_MEM_GB - total_mem_limit_gb
        print(f"  → SAFE: {headroom_gb:.1f}GB headroom before {OVERBOOK_MEM_RATIO}x")
        print(f"  → MEM avg utilization: {total_mem_used_avg/HOST_MEM_GB*100:.1f}%")
        if total_mem_limit_gb > HOST_MEM_GB:
            print(f"  → WARNING: sum of limits ({total_mem_limit_gb:.1f}GB) already > host RAM!")
            print(f"    If all containers hit their limits simultaneously, OOM risk is HIGH")
            print(f"    Strategy: keep sum-of-limits ≤ {OVERBOOK_MEM_RATIO * HOST_MEM_GB:.0f}GB "
                  f"and ensure swap is configured")
    elif mem_overbook_current > OVERBOOK_MEM_RATIO:
        print(f"  → OVERBOOKED DANGEROUSLY: reduce memory limits on oversized containers")

    # ── Actionable recommendations ──────────────────────────────────────────
    print()
    print("=" * 80)
    print(f"RECOMMENDATIONS ({len(recommendations)} services need changes)")
    print("=" * 80)
    print()

    # Sort: biggest potential saves first
    def save_score(r):
        name, actions, lim, rec_cpu, rec_mem_bytes, c_max, m_max = r
        cpu_save = (lim.cpu_limit or 0) - (rec_cpu or 0)
        mem_save = (lim.mem_limit_bytes or 0) - (rec_mem_bytes or 0)
        return cpu_save * 0.5 + mem_save / 1024**3  # normalize roughly

    recommendations.sort(key=save_score, reverse=True)

    for name, actions, lim, rec_cpu, rec_mem_bytes, c_max, m_max in recommendations:
        print(f"  {name}:")
        for a in actions:
            print(f"    → {a}")
        print(f"    (7d max: CPU={fmt_cpu(c_max)}, MEM={fmt_mem(m_max)})")
        print()

    # ── docker-compose snippet ──────────────────────────────────────────────
    print("=" * 80)
    print("docker-compose.yml SNIPPETS (copy-paste)")
    print("=" * 80)
    print()

    for name, actions, lim, rec_cpu, rec_mem_bytes, c_max, m_max in recommendations:
        if rec_cpu or rec_mem_bytes:
            print(f"  # {name}")
            print(f"  deploy:")
            print(f"    resources:")
            if rec_cpu or lim.cpu_reserve:
                print(f"      limits:")
                if rec_cpu:
                    print(f'        cpus: "{rec_cpu}"')
                if rec_mem_bytes:
                    print(f"        memory: {fmt_mem(rec_mem_bytes)}")
                print(f"      reservations:")
                if rec_cpu:
                    print(f'        cpus: "{max(0.05, round(rec_cpu * 0.3 / 0.05) * 0.05):.2f}"')
                if rec_mem_bytes:
                    rec_mem_res = max(32 * 1024**2, rec_mem_bytes // 2)
                    print(f"        memory: {fmt_mem(rec_mem_res)}")
            print()

    print("=" * 80)
    print("STRATEGY SUMMARY")
    print("=" * 80)
    print("""
CPU OVERBOOKING: YES — recommended for this workload
  • Most services have near-zero avg CPU (< 5% of their limit)
  • Linux CFS scheduler handles CPU contention gracefully (throttling, not OOM)
  • Safe to set sum-of-cpu-limits = 2-3x host CPUs for mixed idle/burst workload
  • Recommendation: keep limits tight (130% of observed max), allow 2.5x overbook

MEMORY OVERBOOKING: CAREFUL
  • Memory overbooking causes OOM kills — much more dangerous than CPU throttle
  • Strategy: sum-of-limits should NOT exceed 115% of host RAM (18.4GB total)
  • Set limits = 125% of observed 7d max (already conservative)
  • Reserve = 50% of limit (kernel won't kill unless truly needed)
  • Ensure swap is enabled on host as last-resort buffer (4-8GB swapfile)
  • Mark critical DBs (postgres, mongo, redis) with high oom_score_adj=-500

PRIORITY TIERS:
  1. Databases (postgres, mongo, redis): Never undersize — set limits generously
  2. Active services (immich, jellyfin, stash): Burst-heavy — keep 1.5x headroom
  3. Background/monitor services: Very idle — tighten to 1.2x observed max
  4. One-shot/init containers: No persistent limits needed

OVERBOOKING RISK MITIGATORS:
  - autoheal + healthcheck: already configured (restarts OOM'd containers)
  - oom-watcher: already running (you have this!)
  - Priority: set --oom-kill-disable=false on all (default) but protect DBs
  - Monitor: set alerts if container mem > 80% of limit for > 5m
""")


if __name__ == "__main__":
    main()
