# MCP Server Setup for PotatoStack

Model Context Protocol (MCP) servers let AI coding assistants (Claude Code, OpenCode) query your infrastructure directly.

## Prerequisites

- Node.js 18+ (for npx-based MCP servers)
- Docker (for postgres MCP)
- Running PotatoStack services (prometheus, loki, postgres, searxng)

## Claude Code

The project `.mcp.json` configures all servers automatically. Just run `claude` in the project directory.

Verify with:
```bash
claude mcp list
```

### Manual setup (alternative)

```bash
claude mcp add searxng npx -y searxng-mcp --env SEARXNG_URL=http://localhost:8180
claude mcp add prometheus npx -y prometheus-mcp-server --env PROMETHEUS_URL=http://localhost:9090
claude mcp add loki npx -y @grafana/loki-mcp --env LOKI_URL=http://localhost:3100
claude mcp add postgres docker run -i --rm --network host -e DATABASE_URI crystaldba/postgres-mcp --access-mode=restricted
```

## OpenCode

Add to `opencode.json`:
```json
{
  "mcpServers": {
    "searxng": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "searxng-mcp"],
      "env": { "SEARXNG_URL": "http://localhost:8180" }
    },
    "prometheus": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "prometheus-mcp-server"],
      "env": { "PROMETHEUS_URL": "http://localhost:9090" }
    },
    "loki": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@grafana/loki-mcp"],
      "env": { "LOKI_URL": "http://localhost:3100" }
    },
    "postgres": {
      "type": "stdio",
      "command": "docker",
      "args": ["run", "-i", "--rm", "--network", "host", "-e", "DATABASE_URI", "crystaldba/postgres-mcp", "--access-mode=restricted"],
      "env": { "DATABASE_URI": "postgresql://postgres:YOUR_PASSWORD@localhost:5432/postgres" }
    }
  }
}
```

## Available MCP Servers

| Server | Port | What it does |
|--------|------|-------------|
| SearXNG | 8180 | Web search via privacy-respecting metasearch |
| Prometheus | 9090 | Query metrics (CPU, memory, network, custom) |
| Loki | 3100 | Query container logs |
| PostgreSQL | 5432 | Read-only database queries (restricted mode) |

## Security Notes

- All services bind to `HOST_BIND` (localhost by default)
- Postgres MCP runs in `--access-mode=restricted` (read-only)
- No credentials are embedded in `.mcp.json` — postgres password uses `${POSTGRES_SUPER_PASSWORD}` from environment
- MCP servers run locally, no external network access needed
