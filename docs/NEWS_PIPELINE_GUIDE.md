# News Aggregation Pipeline Guide

news-pipeline fetches RSS feeds and crawls NW.de, extracts full article text via article-extractor (Chromium + Bypass Paywalls Clean), and serves per-source RSS feeds that Miniflux subscribes to. Read on mobile with FeedMe (native Miniflux API).

## Architecture

```
news-pipeline (every 15 min)
  ├── fetches RSS feeds directly (FAZ, HLTV, WB, WSJ)
  ├── crawls 7 NW.de OWL sections (no public RSS)
  ├── extracts full text for each article via article-extractor
  │   ├── FAZ: direct API extraction (bypasses paywall)
  │   ├── NW.de/HLTV: Chromium + Bypass Paywalls Clean extension
  │   ├── WB/WSJ: hard paywall, teaser only (BPC can't bypass)
  │   └── fallback: trafilatura direct fetch
  └── serves per-source RSS feeds on :8085
      ├── /rss/faz   → FAZ articles
      ├── /rss/wsj   → WSJ articles
      ├── /rss/hltv  → HLTV articles
      ├── /rss/wb    → Westfalen-Blatt articles
      ├── /rss/nw    → NW.de articles
      └── /rss       → all sources combined

Miniflux subscribes to each per-source feed with categories:
  ├── News:            FAZ, WSJ
  ├── Counter Strike:  HLTV
  └── Regionale News:  WB, NW.de

article-extractor
  ├── Headless Chromium + Bypass Paywalls Clean extension
  ├── Site-specific API extractors (FAZ)
  ├── trafilatura fallback
  └── Daily BPC auto-update check (every 24h)
```

## Setup

### 1. Start services

```bash
docker compose up -d news-pipeline article-extractor
```

### 2. Feeds and categories

The pipeline automatically registered these feeds in Miniflux:

| Category | Feed | Endpoint | Full text |
|----------|------|----------|-----------|
| News | FAZ | `http://news-pipeline:8085/rss/faz` | Yes (API) |
| News | WSJ | `http://news-pipeline:8085/rss/wsj` | Teaser only (hard paywall) |
| Counter Strike | HLTV | `http://news-pipeline:8085/rss/hltv` | Yes (BPC) |
| Regionale News | WB | `http://news-pipeline:8085/rss/wb` | Teaser only (hard paywall) |
| Regionale News | NW.de | `http://news-pipeline:8085/rss/nw` | Yes (BPC) |

NW.de has no public RSS feed. The pipeline crawls 7 OWL sections, extracts full text via Chromium+BPC, and serves them as a local RSS feed.

### 3. Test

```bash
# Article extractor health
curl http://localhost:8084/health

# Extract a specific article
curl -X POST http://localhost:8084/extract \
  -H "Content-Type: application/json" \
  -d '{"url":"https://www.faz.net/aktuell/"}'

# Check news-pipeline logs
docker logs -f news-pipeline

# Check feed health
docker exec news-pipeline python3 -c "
import urllib.request; print(urllib.request.urlopen('http://localhost:8085/health').read().decode())
"
```

## Reading on Mobile with FeedMe

FeedMe connects to Miniflux directly using its native API support.

### Setup

1. Install **FeedMe** from Play Store
2. Add account → select **Miniflux**
3. Configure:
   - **Server:** `https://potatostack.tale-iwato.ts.net:8093`
   - **Username/Password:** your Miniflux credentials
4. Sync — feeds appear organized by category (News, Counter Strike, Regionale News)

### Tips

- Categories from Miniflux map directly to FeedMe folders
- Full-text articles (FAZ, HLTV, NW.de) render inline — no need to open the browser
- Enable offline sync in FeedMe settings for reading without Tailscale connection

### PWA (Alternative)

Miniflux has a built-in progressive web app:

1. Open `https://potatostack.tale-iwato.ts.net:8093` in your mobile browser (requires Tailscale)
2. Tap the menu → "Install app" or "Add to Home Screen"

## Customization

**Change schedule:** Set `INTERVAL_SECONDS` in `.env` (default 900 = 15 min).

**Add new RSS feeds:** Add entries to the `RSS_FEEDS` list in `scripts/webhooks/news-pipeline.py`, add a source endpoint in `_SOURCE_META`, and register the new feed in Miniflux.

## Troubleshooting

```bash
# Check service logs
docker logs -f article-extractor
docker logs -f news-pipeline

# Test article extraction directly
curl -X POST http://localhost:8084/extract \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com/article"}'

# Health check
curl http://localhost:8084/health

# Check BPC extension version
docker exec article-extractor ls -la /app/bpc-extension/manifest.json

# Force BPC update
docker compose restart article-extractor
```
