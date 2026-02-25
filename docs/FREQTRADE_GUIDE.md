# Freqtrade Integration Guide

Strategy source: `~/workdir/freqtrader-strategy` (point of truth)
Persistent data: `/mnt/ssd/docker-data/freqtrade/user_data/`
UI port: `8181` → Tailscale: `https://potatostack.tale-iwato.ts.net:8181`

---

## Architecture

```
~/workdir/freqtrader-strategy/
├── strategies/          → mounted :ro at /app/strategies AND /app/user_data/strategies
├── config.json          → mounted :ro at /app/config.json
├── user_data/
│   ├── data/            → symlink → /mnt/ssd/docker-data/freqtrade/user_data/data/
│   ├── hyperopt_results/→ symlink → /mnt/ssd/docker-data/freqtrade/user_data/hyperopt_results/
│   ├── backtest_results/→ symlink → /mnt/ssd/docker-data/freqtrade/user_data/backtest_results/
│   └── logs/            → symlink → /mnt/ssd/docker-data/freqtrade/user_data/logs/
```

The symlinks mean `make hyperopt-*` locally and the container both read/write the same SSD data.

---

## How the Bot Works (Historical Data vs Live Trading)

**Historical data is NOT used for live trading.** They are separate concerns:

| Purpose | Data source | When needed |
|---|---|---|
| **Live trading** | Real-time 1h candles fetched from Kraken every hour | Always, automatically |
| **Backtesting** | Downloaded historical OHLCV | Before validating strategy changes |
| **Hyperopt** | Downloaded historical OHLCV | Before tuning params |

The bot fetches live candles from Kraken, reads the current regime from Redis (written by
`regime-classifier`), delegates to the correct scenario (A/B/C/D), and fires buy/sell orders
**automatically** — no manual action needed.

### What triggers a trade

1. A new 1h candle closes on Kraken
2. Bot runs `populate_indicators` + `populate_entry_trend` on that candle
3. Strategy votes on indicator signals through `IndicatorVoter`
4. If vote crosses threshold AND regime conditions are met → entry order placed
5. Exit fires when ROI, stoploss, or sell signal triggers

### Current live state (as of setup)

```
State:     RUNNING  (dry_run — simulated, no real money)
Regime:    A — Quiet Growth (59.5% confidence, from regime-classifier)
Pairs:     18 EUR pairs from pairs-screener
Params:    DEFAULT (buy_rsi=30, sell_rsi=70) — conservative until hyperopt runs
```

`buy_rsi=30` is deeply oversold — trades fire when conditions are right, not constantly.
The `correlation_gate` warnings for individual pairs are **expected** (filters redundant indicators).

---

## Credentials

Stored in `potatostack/.env`:

```
FREQTRADE_API_USERNAME=freqtrader
FREQTRADE_API_PASSWORD=iBuwP35TmhaoFkr1WAhKXTWMejE
FREQTRADE_JWT_SECRET=8778dc2bb7e8ff42d3e7644ddad441a28832c42b3a1562ef809e6102bc8a27b7
```

Injected via `FREQTRADE__API_SERVER__*` env vars in docker-compose (freqtrade's built-in override format).

---

## FreqUI Login

FreqUI is a multi-bot dashboard — register the bot once per browser.

1. Open `https://potatostack.tale-iwato.ts.net:8181`
2. Click **"Login to bot"** (or "Add Bot")
3. Fill in:
   ```
   Bot Name:  PotatoStack         (anything)
   API Url:   https://potatostack.tale-iwato.ts.net:8181
   Username:  freqtrader
   Password:  iBuwP35TmhaoFkr1WAhKXTWMejE
   ```

The "API Url" field is required — FreqUI does not auto-detect it.

**Where to see performance after login:**
- **Dashboard** — open trades, P&L, win rate, drawdown, balance
- **Chart** — candlestick with buy/sell signal overlays per pair
- **Trades** — full closed trade history with individual P&L

---

## Download Historical Data

Kraken does **not** support standard OHLCV download — must use `--dl-trades`
(downloads raw trades, resamples to OHLCV — slow, ~30–60 min per run, hits rate limits).
Strategy only uses `1h` timeframe so only that needs to be downloaded.

```bash
# Initial / periodic refresh (via container):
docker exec freqtrade-bot freqtrade download-data \
  --config /app/config.json \
  --pairs BTC/EUR ETH/EUR SOL/EUR XRP/EUR LTC/EUR LINK/EUR \
  --days 30 --timeframes 1h --dl-trades

# Or from workdir (uses same SSD data via symlinks):
cd ~/workdir/freqtrader-strategy && make download-data
```

Data lands in `/mnt/ssd/docker-data/freqtrade/user_data/data/kraken/`.

**Note:** Files only appear on disk after each pair fully completes — nothing visible mid-run.

---

## Data Download Frequency

| Situation | Action |
|---|---|
| **Live trading** | Never — bot fetches live candles automatically |
| **Before hyperopt** | Only if last download is >30 days old |
| **Before backtesting** | Only if testing a newer time window |
| **Initial setup** | Once (Dagu handles weekly incremental updates after that) |

Dagu runs an incremental 7-day refresh every Sunday before the hyperopt check.

---

## Backtesting

Run after download completes. One-off validation — not scheduled.

```bash
docker exec freqtrade-bot freqtrade backtesting \
  --config /app/config.json \
  --strategy AdaptiveRegimeStrategy \
  --strategy-path /app/strategies/ \
  --timerange 20250101-20250225

# Or from workdir:
cd ~/workdir/freqtrader-strategy && make run-backtest
```

---

## Hyperopt (Hyperparameter Tuning)

Replaces the default `buy_rsi=30 / sell_rsi=70` with regime-tuned params.
Run AFTER download has data. Results persist to `user_data/hyperopt_results/`.
Safe to run alongside the live bot (uses separate in-memory DB, doesn't touch live trades).

```bash
# Run for all regimes via automation script:
docker exec freqtrade-bot \
  python /app/scripts/run_auto_refit.py /app/user_data/logs/refit_decision.json

# Or manually per regime via Makefile:
cd ~/workdir/freqtrader-strategy
make hyperopt-a   # Regime A: Quiet Growth
make hyperopt-b   # Regime B: Walsh Contraction
make hyperopt-c   # Regime C: Fragmented Range
make hyperopt-d   # Regime D: Black Swan

# Show best params after hyperopt:
make hyperopt-show

# Performance-triggered auto-refit (checks gates first):
make hyperopt-check   # show refit status for all regimes
make hyperopt-auto    # refit only failing regimes
```

New params are deployed **immediately** on the next candle close — no restart needed.

### Hyperopt gates (for automated refit)

Auto-refit only fires when ALL 3 gates fail:
1. **Data gate** — enough new trades since last refit
2. **Decay gate** — rolling OOS Sharpe dropped >30% below baseline OR below floor (0.3)
3. **Cooldown** — at least 7 days since last refit

New params only deployed if new OOS Sharpe beats current by ≥ 0.05.

---

## When to Run Backtesting / Hyperopt

**Backtesting** — manually, when:
- You changed strategy logic and want to validate
- After hyperopt, to confirm new params improve out-of-sample performance

**Hyperopt** — let Dagu handle it automatically (weekly Sunday 3am).
Manual trigger: `make hyperopt-auto` or open `freqtrade-weekly` DAG in Dagu and click **Run**.

---

## Dagu Automation

DAG: `config/dagu/dags/freqtrade-weekly.yaml` — runs **Sunday 03:00**

```
refresh-data  →  check-refit  →  run-hyperopt  →  notify-success
```

- `refresh-data`: incremental 7-day `download-data --dl-trades` for 8 EUR pairs
- `check-refit`: runs `check_refit.py --json`, writes decision to `user_data/logs/refit_decision.json`
- `run-hyperopt`: runs `run_auto_refit.py` — refits failing regimes, validates OOS, deploys if improved
- All steps run via `docker exec freqtrade-bot` (safe alongside live trading)

To trigger manually: open the `freqtrade-weekly` DAG in Dagu UI and click **Run**.

---

## Rebuilding the Image

Required when changing `Dockerfile` or `pyproject.toml` in the strategy project.

```bash
cd ~/potatostack
docker compose build freqtrade-bot
docker compose up -d --force-recreate freqtrade-bot
```

The `freqtrade install-ui` step runs at build time — no manual UI install needed.

---

## Recreating user_data Symlinks

If the symlinks are ever lost (e.g. after re-cloning the strategy repo):

```bash
PROJ=~/workdir/freqtrader-strategy/user_data
SSD=/mnt/ssd/docker-data/freqtrade/user_data

mkdir -p $SSD/{data,hyperopt_results,backtest_results,logs,notebooks,plot,strategies}

for d in data hyperopt_results backtest_results logs; do
  rm -rf $PROJ/$d
  ln -s $SSD/$d $PROJ/$d
done
```

---

## Rotating Credentials

1. Generate new values:
   ```bash
   python3 -c "import secrets; print(secrets.token_hex(32)); print(secrets.token_urlsafe(20))"
   ```
2. Update `FREQTRADE_API_PASSWORD` and `FREQTRADE_JWT_SECRET` in `potatostack/.env`
3. Restart: `docker compose up -d --force-recreate freqtrade-bot`

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| FreqUI shows "No bots" | Normal first-run — go through "Add Bot" flow, enter API Url manually |
| Login returns 401 | Check `FREQTRADE_API_PASSWORD` in `.env` matches what you type |
| `download-data` fails "Historic klines not available" | Add `--dl-trades` (Kraken limitation) |
| No data files after download | Normal — files only appear after each pair fully completes |
| No trades after startup | Bot needs a buy signal; default params (rsi=30) are conservative |
| `correlation_gate blocked` in logs | Expected — filters redundant indicators, not an error |
| Strategies not found | `docker exec freqtrade-bot ls /app/strategies/` |
| Hyperopt results gone after re-clone | Recreate symlinks (see above) |
| Container won't start | `docker logs freqtrade-bot --tail 50` |
