# setup-dev-terminal

> 🚀 One-command dev terminal setup for coding agents (Ghostty + zellij + Nerd Font) on macOS

A single idempotent shell script that installs and configures a modern terminal
environment tuned for AI coding agents (Claude Code, Codex CLI, Gemini CLI,
OpenCode, pi, …) — GPU-rendered terminal, multiplexer, a complete Nerd Font,
and a full zsh stack (zsh + oh-my-zsh + plugins).

## ✨ What it installs

| Tool | Why |
|---|---|
| [Ghostty](https://ghostty.org) | Fast GPU-rendered terminal, the 2025 community favorite |
| [zellij](https://zellij.dev) | Terminal multiplexer with a friendly UI (tmux alternative) |
| JetBrainsMono Nerd Font | Full-weight monospace font with 3,000+ icons |
| [zsh](https://zsh.org) | Latest zsh via Homebrew |
| [oh-my-zsh](https://ohmyz.sh) | Popular zsh framework (non-interactive install) |
| zsh-syntax-highlighting / zsh-autosuggestions | Essential zsh plugins, auto-enabled in `.zshrc` |
| [uv](https://docs.astral.sh/uv/) | Fast Python package manager |
| [bun](https://bun.com) | All-in-one JS runtime & package manager |
| oh-my-pi (`omp`) | `@oh-my-pi/pi-coding-agent`, installed via `omp.sh` |
| [nvm](https://github.com/nvm-sh/nvm) + Node.js | Node version manager + Node `24` (with npm) |

It also links the Ghostty CLI, writes sane configs (Dracula theme, font, padding,
scrollback), sets `ZSH_THEME` + `plugins=()` in `~/.zshrc` (with backup), and
optionally auto-starts zellij inside Ghostty.

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
| `INSTALL_ZSH` | `1` | Set `0` to skip the zsh stack (zsh / oh-my-zsh / plugins) |
| `ZSH_THEME_NAME` | `ys` | oh-my-zsh theme to set in `~/.zshrc` |
| `ZSH_PLUGINS` | `git z zsh-syntax-highlighting zsh-autosuggestions` | Plugins to clone & enable |
| `INSTALL_DEVTOOLS` | `1` | Set `0` to skip all dev tools below |
| `INSTALL_UV` / `INSTALL_BUN` / `INSTALL_OMP` / `INSTALL_NVM` | `1` | Disable individually with `0` |
| `NODE_VERSION` | `24` | Node version to install via nvm |
| `NVM_NODEJS_ORG_MIRROR` | *(empty)* | Optional mirror for nvm downloads (e.g. `https://npmmirror.com/mirrors/node/`) |

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

zsh plugins take effect in new terminals. If your login shell is still the
system zsh, switch it with `chsh -s $(which zsh)`.

nvm and Node take effect in new terminals (`nvm use 24`).
Run `omp` to start oh-my-pi.

## 🧰 Requirements

- macOS
- [Homebrew](https://brew.sh)

## 📄 License

[MIT](./LICENSE)
