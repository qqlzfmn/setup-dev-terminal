# setup-dev-terminal

> 🚀 One-command dev terminal setup for coding agents (Ghostty + zellij + Nerd Font) on macOS

A single idempotent shell script that installs and configures a modern terminal
environment tuned for AI coding agents (Claude Code, Codex CLI, Gemini CLI,
OpenCode, pi, …) — GPU-rendered terminal, multiplexer, and a complete Nerd Font.

## ✨ What it installs

| Tool | Why |
|---|---|
| [Ghostty](https://ghostty.org) | Fast GPU-rendered terminal, the 2025 community favorite |
| [zellij](https://zellij.dev) | Terminal multiplexer with a friendly UI (tmux alternative) |
| JetBrainsMono Nerd Font | Full-weight monospace font with 3,000+ icons |

It also links the Ghostty CLI, writes sane configs (Dracula theme, font, padding,
scrollback), and optionally auto-starts zellij inside Ghostty.

## 🚀 Usage

```bash
bash setup-dev-terminal.sh
```

That's it. Open Ghostty and you're inside zellij.

## 🔁 Idempotent & safe

Runs are **idempotent** — safe to re-run any time:

- Already-installed packages are skipped
- Config files are only written when content differs
- Old configs are backed up as `*.bak.<timestamp>` before being overwritten
- The zshrc auto-start block is never appended twice

## 🎛️ Configuration

Override via environment variables:

| Variable | Default | Description |
|---|---|---|
| `GHOSTTY_THEME` | `Dracula` | Ghostty theme name (see `ghostty +list-themes`) |
| `ZELLIJ_THEME` | `dracula` | zellij theme name |
| `FONT_FAMILY` | `JetBrainsMono Nerd Font Mono` | Terminal font family |
| `FONT_SIZE` | `14` | Terminal font size |
| `ZELLIJ_AUTOSTART` | `1` | Set `0` to disable auto-starting zellij |

Example:

```bash
FONT_SIZE=13 ZELLIJ_THEME=catppuccin-mocha bash setup-dev-terminal.sh
```

## 🎹 Cheat sheet

| Keys | Action |
|---|---|
| `Ctrl+p` then `n` / `d` / `r` / `x` | New pane / split down / split right / close |
| `Ctrl+t` then `n` | New tab |
| `Ctrl+o` then `d` | Detach (back to bare shell) |
| `Ctrl+o` then `x` | Exit zellij |

To stop the auto-start: set `ZELLIJ_AUTOSTART=0` in `~/.zshrc`.

## 🧰 Requirements

- macOS
- [Homebrew](https://brew.sh)

## 📄 License

[MIT](./LICENSE)
