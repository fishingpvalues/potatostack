# Atuin Cross-Platform Guide (Mac, Linux, Windows)

Atuin syncs your shell history across devices. The server is already in the stack (`atuin`).

## 1) Server URL

Use the Traefik URL:

```
https://atuin.<HOST_DOMAIN>
```

If you're accessing via Tailscale HTTPS (see `TAILSCALE_ACCESS.md`), use:

```
https://potatostack.<tailnet>.ts.net:8889
```

## 2) Install Atuin Client

Pick one of these:

**macOS (Homebrew)**
```
brew install atuin
```

**Linux (Rust/Cargo)**
```
cargo install atuin
```

**Windows (PowerShell + Cargo)**
```
cargo install atuin
```

## 3) First-Time Setup

Register and login:
```
atuin register -u <username> -e <email>
atuin login -u <username>
```

Set the server (if not auto-detected):
```
atuin config set sync.address https://atuin.<HOST_DOMAIN>
```

## 4) Enable in Zsh (Mac + Linux)

Add to `~/.zshrc`:
```
eval "$(atuin init zsh)"
```

Then reload:
```
source ~/.zshrc
```

## 5) Import Existing Zsh History (Mac + p10k)

Make sure Zsh writes history to a file:
```
echo 'HISTFILE=~/.zsh_history' >> ~/.zshrc
echo 'setopt INC_APPEND_HISTORY' >> ~/.zshrc
echo 'setopt SHARE_HISTORY' >> ~/.zshrc
```

Import into Atuin:
```
atuin import zsh
```

If your history file contains binary data, normalize first:
```
strings ~/.zsh_history > /tmp/zsh_history.txt
HISTFILE=/tmp/zsh_history.txt atuin import zsh
```

## 6) Sync Across Devices

```
atuin sync
```

## Troubleshooting

- **Registration closed**: set `ATUIN_OPEN_REGISTRATION=true` temporarily in `.env`.
- **Wrong server URL**: check `atuin config get sync.address`.
- **No history showing**: confirm `~/.zsh_history` exists and has entries, then re-run `atuin import zsh`.
