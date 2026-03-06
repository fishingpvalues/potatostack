#!/usr/bin/env python3
"""
Stash job submitter + poller for Dagu workflows.

Usage: stash-job.py <operation> [poll_sec] [timeout_sec]
Operations: scan | generate | autotag | identify
"""

import json
import sys
import time
import urllib.request

STASH_URL = "http://gluetun:9900/graphql"

MUTATIONS = {
    "scan": {
        "field": "metadataScan",
        "query": """mutation {
  metadataScan(input: {
    scanGenerateCovers: false
    scanGeneratePreviews: false
    scanGenerateImagePreviews: false
    scanGenerateSprites: false
    scanGeneratePhashes: false
    scanGenerateThumbnails: false
    scanGenerateClipPreviews: false
  })
}""",
    },
    "generate": {
        "field": "metadataGenerate",
        "query": """mutation {
  metadataGenerate(input: {
    covers: true
    previews: true
    imagePreviews: false
    sprites: true
    phashes: true
    imageThumbnails: false
    clipPreviews: false
    markers: true
    markerImagePreviews: true
    markerScreenshots: true
    transcodes: false
    interactiveHeatmapsSpeeds: true
    overwrite: false
  })
}""",
    },
    "autotag": {
        "field": "metadataAutoTag",
        "query": """mutation {
  metadataAutoTag(input: {
    performers: ["*"]
    studios: ["*"]
    tags: ["*"]
  })
}""",
    },
    "identify": {
        "field": "metadataIdentify",
        "query": """mutation {
  metadataIdentify(input: { sources: [] })
}""",
    },
}


def gql(query: str) -> dict:
    data = json.dumps({"query": query}).encode()
    req = urllib.request.Request(
        STASH_URL,
        data=data,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in MUTATIONS:
        print(f"Usage: stash-job.py <{'|'.join(MUTATIONS)}>  [poll_sec]  [timeout_sec]")
        sys.exit(1)

    op = sys.argv[1]
    poll_interval = int(sys.argv[2]) if len(sys.argv) > 2 else 15
    timeout = int(sys.argv[3]) if len(sys.argv) > 3 else 28800  # 8h default

    print(f"[stash] Submitting: {op}")
    try:
        result = gql(MUTATIONS[op]["query"])
    except Exception as e:
        print(f"[stash] Failed to submit mutation: {e}")
        sys.exit(1)

    if "errors" in result:
        print(f"[stash] GraphQL errors: {result['errors']}")
        sys.exit(1)

    job_id = result["data"].get(MUTATIONS[op]["field"])
    if not job_id:
        print("[stash] No job ID returned — job skipped or completed immediately")
        sys.exit(0)

    print(f"[stash] Job ID: {job_id}")
    start = time.time()

    while time.time() - start < timeout:
        time.sleep(poll_interval)
        elapsed = int(time.time() - start)
        try:
            r = gql(
                f'{{ findJob(input: {{id: "{job_id}"}}) {{ id status progress error }} }}'
            )
        except Exception as e:
            print(f"[stash] Poll error (will retry): {e}")
            continue

        job = r["data"].get("findJob")
        if not job:
            print(f"[stash] {elapsed}s: job {job_id} disappeared from queue")
            sys.exit(1)

        status = job["status"]
        progress = job.get("progress") or 0
        print(f"[stash] {elapsed}s: {status} ({progress:.0%})")

        if status == "FINISHED":
            print(f"[stash] {op} finished successfully")
            sys.exit(0)

        if status in ("STOPPED", "CANCELLED"):
            err = job.get("error") or ""
            if err:
                print(f"[stash] {op} stopped with error: {err}")
                sys.exit(1)
            # STOPPED without error = cancelled or no-op (e.g. nothing to identify)
            print(f"[stash] {op} stopped cleanly (no error)")
            sys.exit(0)

    print(f"[stash] Timeout after {timeout}s waiting for {op}")
    sys.exit(1)


if __name__ == "__main__":
    main()
