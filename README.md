# setup-dev-terminal

> 🚀 One-command dev terminal setup for coding agents (Ghostty + herdr + Nerd Font) on macOS & Linux

A single idempotent shell script that installs and configures a modern terminal
environment tuned for AI coding agents (Claude Code, Codex CLI, Gemini CLI,
OpenCode, pi, …) — GPU-rendered terminal, multiplexer, a complete Nerd Font,
and a full zsh stack (zsh + oh-my-zsh + plugins).

Runs on **macOS** (Homebrew) and **Linux** (apt / dnf / pacman / zypper / apk /
emerge / xbps / nix). Components that cannot work on the current system are
**greyed out and unselectable** in the menu — for example Ghostty on a headless
server, or herdr on an architecture with no prebuilt binary.

## 🖥️ Platform support

| Component | macOS | Linux (desktop) | Linux (headless) | Notes |
|---|---|---|---|---|
| Ghostty | ✅ cask | ✅ distro pkg | 🚫 needs a display | GUI app; needs GTK4 + libadwaita + OpenGL |
| herdr | ✅ | ✅ | ✅ | static binary; x86_64 + aarch64 only |
| Nerd Font | ✅ cask | ✅ pkg or user fonts | ✅ | falls back to `~/.local/share/fonts` + `fc-cache` |
| zsh stack | ✅ | ✅ | ✅ | oh-my-zsh + plugins |
| uv / bun / omp | ✅ | ✅ | ✅ | x86_64 + aarch64 |
| nvm + Node | ✅ | ✅ | ✅ | |
| agent skills | ✅ | ✅ | ✅ | needs node/npx |

Ghostty packaging by distro: **Arch, openSUSE, Gentoo, Void, Solus, Alpine,
NixOS** ship it in official repos; **Ubuntu 26.04+** has it in `universe`;
**Fedora/RHEL** need the `scottames/ghostty` COPR; **Debian** and older Ubuntu
need the community `.deb`; any distro can use the AppImage. The script prints
the right command for your distro when a package isn't available.

## ✨ What it installs

| Tool | Why |
|---|---|
| [Ghostty](https://ghostty.org) | Fast GPU-rendered terminal, the 2025 community favorite |
| [herdr](https://herdr.dev) | Terminal workspace manager for AI coding agents (tmux alternative) |
| [herdr skill](https://herdr.dev/docs/agent-skill/) | Teaches coding agents to drive herdr panes from inside a pane |
| [agent skills](https://skills.sh) | Curated agent skills via `npx skills` (mattpocock, opencli, cnb, cli-anything, …) |
| JetBrainsMono Nerd Font | Full-weight monospace font with 3,000+ icons |
| [zsh](https://zsh.org) | Latest zsh (Homebrew on macOS, distro package on Linux) |
| [oh-my-zsh](https://ohmyz.sh) | Popular zsh framework (non-interactive install) |
| zsh-syntax-highlighting / zsh-autosuggestions | Essential zsh plugins, auto-enabled in `.zshrc` |
| [uv](https://docs.astral.sh/uv/) | Fast Python package manager |
| [bun](https://bun.com) | All-in-one JS runtime & package manager |
| oh-my-pi (`omp`) | `@oh-my-pi/pi-coding-agent`, installed via `omp.sh` |
| [nvm](https://github.com/nvm-sh/nvm) + Node.js | Node version manager + Node `24` (with npm) |

It also links the Ghostty CLI, writes sane configs (Dracula theme, font, padding,
scrollback), sets `ZSH_THEME` + `plugins=()` in `~/.zshrc` (with backup), installs
the herdr agent skill, and optionally auto-starts herdr inside Ghostty.

## ⚡ One-line install

**交互式**（推荐，保留复选框菜单）：

```bash
curl -fsSL https://raw.githubusercontent.com/qqlzfmn/setup-dev-terminal/main/setup-dev-terminal.sh -o /tmp/setup-dev-terminal.sh && bash /tmp/setup-dev-terminal.sh
```

**非交互**（环境变量默认全装，适合 CI/管道）：

```bash
curl -fsSL https://raw.githubusercontent.com/qqlzfmn/setup-dev-terminal/main/setup-dev-terminal.sh | bash
```

> 💡 `curl | bash` 管道会丢失 TTY，交互式复选框菜单不会出现，会直接按默认全装。所以想交互选择时必须先用 `-o` 下载到文件再执行。

## 🚀 Usage

```bash
bash setup-dev-terminal.sh
```

An **interactive checkbox menu** lets you pick which components to install
(space to toggle, `j/k` or arrows to move, enter to confirm):

```text
安装项 (j/k或↑↓移动 · 空格勾选 · 回车确认 · q退出)
────────────────────────────────────────
▶ [x] Ghostty 终端 (GPU 渲染)
  [x] herdr 终端复用 (多窗口/pane)
  [x] JetBrainsMono Nerd Font (图标字体)
  [x] zsh 栈: zsh + oh-my-zsh + 插件
  [x] uv Python 包管理器
  [x] bun JS 运行时/包管理器
  [x] oh-my-pi (omp) 开发助手
  [x] nvm + Node 24
  [x] agent skills (npx skills, 需 node)
────────────────────────────────────────
```

Pure bash + ANSI, **zero dependencies**, compatible with bash 3.2 (macOS system shell).

For non-interactive / CI usage, keep the env-var defaults:

```bash
SKIP_INTERACTIVE=1 bash setup-dev-terminal.sh
```

## 🔁 Idempotent & safe

Runs are **idempotent** — safe to re-run any time:

- Already-installed packages are skipped
- System-provided tools (`/bin/zsh`, `/usr/bin/curl`, `/usr/bin/git`) are detected
  via `command -v` / `which` and skipped — no needless Homebrew reinstall
  (override with `FORCE_BREW_TOOLS=1`)
- Config files are only written when content differs
- Old configs are backed up as `*.bak.<timestamp>` before being overwritten
- The zshrc auto-start block is never appended twice
- The herdr agent skill is skipped when already installed

## 🎛️ Configuration

Override via environment variables:

| Variable | Default | Description |
|---|---|---|
| `GHOSTTY_THEME` | `Dracula` | Ghostty theme name (see `ghostty +list-themes`) |
| `HERDR_THEME` | `dracula` | herdr theme name (see `herdr --default-config`) |
| `FONT_FAMILY` | `JetBrainsMono Nerd Font Mono` | Terminal font family |
| `FONT_SIZE` | `14` | Terminal font size |
| `HERDR_AUTOSTART` | `1` | Set `0` to disable auto-starting herdr |
| `INSTALL_SKILLS` | `1` | Set `0` to skip agent skills (needs node/npx); edit `SKILL_PACKAGES` to change the set |
| `INSTALL_ZSH` | `1` | Set `0` to skip the zsh stack (zsh / oh-my-zsh / plugins) |
| `ZSH_THEME_NAME` | `ys` | oh-my-zsh theme to set in `~/.zshrc` |
| `ZSH_PLUGINS` | `git z zsh-syntax-highlighting zsh-autosuggestions` | Plugins to clone & enable |
| `INSTALL_DEVTOOLS` | `1` | Set `0` to skip all dev tools below |
| `INSTALL_GHOSTTY` / `INSTALL_HERDR` / `INSTALL_FONT` / `INSTALL_ZSH` | `1` | Toggle each component (also honored as interactive defaults) |
| `INSTALL_UV` / `INSTALL_BUN` / `INSTALL_OMP` / `INSTALL_NVM` | `1` | Disable individually with `0` |
| `NODE_VERSION` | `24` | Node version to install via nvm |
| `NVM_NODEJS_ORG_MIRROR` | *(empty)* | Optional mirror for nvm downloads (e.g. `https://npmmirror.com/mirrors/node/`) |
| `FORCE_BREW_TOOLS` | `0` | Set `1` to force Homebrew install of zsh/curl/git (default: skip if system-provided) |
| `INSTALL_BREW` | `1` | Auto-install Homebrew if missing (macOS only); set `0` to fail with a hint instead |
| `FORCE_GUI` | `0` | Set `1` to allow Ghostty even without `DISPLAY`/`WAYLAND_DISPLAY` (e.g. WSL, remote X) |

Example:

```bash
FONT_SIZE=13 HERDR_THEME=catppuccin bash setup-dev-terminal.sh
```

## 🎹 Cheat sheet

| Keys | Action |
|---|---|
| `Ctrl+b` then `v` / `-` | Split right / split down |
| `Ctrl+b` then `c` | New tab |
| `Ctrl+b` then `q` | Detach (back to bare shell) |
| `Ctrl+b` then `?` | Show all active keybindings |

To stop the auto-start: set `HERDR_AUTOSTART=0` in `~/.zshrc`.

herdr is mouse-first: click panes and tabs, drag split borders, right-click for
menus. See the [keyboard docs](https://herdr.dev/docs/keyboard/) for a
prefix-free setup.

Agent skills install to `~/.agents/skills/` via `npx skills add … -g`, and most
agents (Claude Code, Codex, OpenCode, …) pick them up automatically. The set is
declared in `SKILL_PACKAGES` near the top of the script — one
`"<source>|<skill names>"` entry per source:

```bash
SKILL_PACKAGES=(
  "herdrdev/herdr|herdr"
  "mattpocock/skills|code-review tdd research ..."   # only these are installed
  "some/other-repo|*"                                # * = every skill in the source
)
```

A space-separated list installs only those skills; `*` installs everything the
source publishes. Re-runs skip a source whose skills are already present (a
source that lists names is checked per-skill, so a half-finished install is
completed on the next run). Skip the whole step with `INSTALL_SKILLS=0`.

> `*` can be large: `hkuds/cli-anything` ships 72 skills. Name them explicitly
> if you only want a few.
>
> Name collisions resolve by order — a later source overwrites an earlier one.
> `herdrdev/herdr` and `mattpocock/skills` both publish `triage`; the order
> above keeps mattpocock's version.

The herdr skill is special-cased: it also installs from the herdr binary itself
(`herdr --skill`), so it works even without node/npx.

zsh plugins take effect in new terminals. If your login shell is still the
system zsh, switch it with `chsh -s $(which zsh)`.

nvm and Node take effect in new terminals (`nvm use 24`).
Run `omp` to start oh-my-pi.

## 🧰 Requirements

- **macOS** (Apple Silicon or Intel) or **Linux** (x86_64 / aarch64 recommended)
- macOS: [Homebrew](https://brew.sh) — **auto-installed** if missing
  (official installer, may prompt for sudo; disable with `INSTALL_BREW=0`)
- Linux: `sudo` access for system packages (a `curl`/`git` install needs none)
- `curl` is required; `unzip` is used for the font fallback on Linux

Unsupported combinations are detected and skipped automatically — you don't need
to remember the table above.

## 📄 License

[MIT](./LICENSE)
