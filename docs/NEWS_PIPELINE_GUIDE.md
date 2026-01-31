# News Aggregation Pipeline Guide

Article Extractor + news-pipeline container for keyword-based ntfy alerts.

Sources: HLTV, FAZ, Neue Westfälische, Westfalenblatt.

## Architecture

```
Miniflux (RSS reader)

news-pipeline (every 15 min)
  → fetches unread Miniflux entries
  → if content < 500 chars → calls Article Extractor
  → Article Extractor tries trafilatura, detects paywalls, falls back to newspaper3k
  → updates Miniflux entry with full text
  → if keywords match → sends ntfy alert to "news-alerts" topic
      → tap notification → opens article in Miniflux via Tailscale
      → "Open source" action → opens original URL
```

## Setup

### 1. Start services

```bash
docker compose up -d news-pipeline article-extractor
```

### 2. Add RSS feeds to Miniflux

Open Miniflux and add feeds directly (RSS/Atom URLs).

### 3. Get a Miniflux API key

1. Open Miniflux → **Settings → API Keys → Create a new API key**
2. Copy the key
3. Update `.env`:
   ```
   MINIFLUX_API_KEY=your_actual_key_here
   ```

### 4. Configure keywords (optional)

Override the default keyword regex in `.env`:
```
KEYWORD_PATTERN=(cs2|counter-strike|hltv|bielefeld|owl|paderborn|\bnw\b|westfalen)
```

### 5. Test

```bash
# Article extractor works
curl -X POST http://localhost:8084/extract \
  -H "Content-Type: application/json" \
  -d '{"url":"https://www.hltv.org"}'

# Check news-pipeline logs
docker logs -f news-pipeline
```

### 6. Subscribe to ntfy alerts

Subscribe to the `news-alerts` topic in the ntfy app or check `http://localhost:8089/news-alerts`.

## Reading on Mobile

### PWA (Recommended)

Miniflux has a built-in progressive web app. On your phone:

1. Open `https://potatostack.tale-iwato.ts.net:8093` in your browser (requires Tailscale)
2. **iOS:** Tap Share → "Add to Home Screen"
3. **Android:** Tap the menu → "Install app" or "Add to Home Screen"

The PWA works offline for already-loaded articles and feels like a native app.

### Native RSS Reader (Fever API)

Miniflux supports the Fever API for use with native mobile RSS apps (Unread, Reeder, NetNewsWire, etc.):

1. In Miniflux → **Settings → Integrations → Fever**
2. Set a username and password, then click **Activate**
3. In your RSS app, add a Fever account with:
   - **Server:** `https://potatostack.tale-iwato.ts.net:8093/fever/`
   - **Username/Password:** as configured above

## Miniflux Tips

- **Enable scraper per feed:** Feed settings → check "Fetch original content" to have Miniflux scrape full articles automatically (reduces need for Article Extractor)
- **Categories:** Organize feeds into categories (News, Gaming, Local) for easier reading
- **Entry limits:** Feed settings → "Keep N entries" to prevent feed bloat on high-volume sources
- **Keyboard shortcuts:** `n`/`p` navigate entries, `v` opens original, `m` toggles read, `f` stars

## Customization

**Add/change keywords:** Set `KEYWORD_PATTERN` in `.env` and restart news-pipeline.

**Change schedule:** Set `INTERVAL_SECONDS` in `.env` (default 900 = 15 min).

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
```
