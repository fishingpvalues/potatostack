# News Aggregation Pipeline Guide

RSS-Bridge + Article Extractor + n8n workflow for keyword-based ntfy alerts.

Sources: HLTV, FAZ, Neue Westfälische, Westfalenblatt.

## Architecture

```
Miniflux (RSS reader)
  ↑ feeds from
RSS-Bridge (generates feeds for sites without RSS)

n8n (every 15 min)
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
docker compose up -d n8n rss-bridge article-extractor
```

### 2. Add RSS feeds to Miniflux

Open Miniflux and add feeds. For sites without native RSS, use RSS-Bridge at `http://localhost:3007`:

| Source | Method |
|---|---|
| HLTV | RSS-Bridge → select `Hltv` bridge → copy feed URL → add to Miniflux |
| FAZ | Direct: `https://www.faz.net/rss/aktuell/` or use RSS-Bridge `CssBridge` for specific sections |
| Neue Westfälische | RSS-Bridge → `CssBridge` or `XPathBridge` → enter NW URL, configure CSS selectors |
| Westfalenblatt | RSS-Bridge → `CssBridge` or `XPathBridge` → enter URL, configure CSS selectors |

When adding RSS-Bridge feeds to Miniflux, use the internal Docker URL:
```
http://rss-bridge:80/?action=display&bridge=Hltv&format=Atom
```

### 3. Get a Miniflux API key

1. Open Miniflux → **Settings → API Keys → Create a new API key**
2. Copy the key
3. Update `.env`:
   ```
   MINIFLUX_API_KEY=your_actual_key_here
   ```

### 4. Import the n8n workflow

1. Open n8n at `http://localhost:5678`
2. Create your admin account on first login
3. Go to **Workflows → Import from File**
4. Select `scripts/n8n/news-pipeline-workflow.json`

### 5. Configure the workflow in n8n

1. Open the imported workflow
2. Add environment variable: **Settings → Variables** → add `MINIFLUX_API_KEY` with your key
3. Open the **"Keyword Match?"** node and set the regex condition value to:
   ```
   (cs2|counter-strike|hltv|bielefeld|owl|paderborn|\bnw\b|westfalen)
   ```
4. **Activate** the workflow (toggle in top-right)

### 6. Test

```bash
# RSS-Bridge is up
curl -s http://localhost:3007 | head -5

# Article extractor works
curl -X POST http://localhost:8084/extract \
  -H "Content-Type: application/json" \
  -d '{"url":"https://www.hltv.org"}'

# Or trigger the n8n workflow manually via the UI ("Test Workflow" button)
```

### 7. Subscribe to ntfy alerts

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

**Add/change keywords:** Edit the "Keyword Match?" node regex in n8n.

**Change schedule:** Edit the "Every 15 min" trigger node in n8n.

**Add more sources:** Add feeds in Miniflux. If the site has no RSS, create a bridge in RSS-Bridge first. The whitelist at `config/rssbridge/whitelist.txt` controls which bridges are enabled.

## Troubleshooting

```bash
# Check service logs
docker logs -f rss-bridge
docker logs -f article-extractor
docker logs -f n8n

# Test article extraction directly
curl -X POST http://localhost:8084/extract \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com/article"}'

# Health check
curl http://localhost:8084/health
```
