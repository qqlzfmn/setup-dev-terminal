#!/usr/bin/env bash
# ============================================================
# 开发终端一键安装脚本 (macOS + Homebrew)
#
# 安装: Ghostty + zellij + JetBrainsMono Nerd Font + zsh 栈(zsh + oh-my-zsh + 插件)
# 配置: Ghostty 字体/主题 + zellij 主题 + zshrc(zellij 自动启动 + oh-my-zsh 主题/插件)
#
# 用法:   bash setup-dev-terminal.sh
# 幂等:   可重复运行, 已装的跳过, 配置相同不覆盖, zshrc 不重复追加
# 环境变量可覆盖:
#   GHOSTTY_THEME=Dracula  ZELLIJ_THEME=dracula  FONT_FAMILY="JetBrainsMono Nerd Font Mono"
#   FONT_SIZE=14  ZELLIJ_AUTOSTART=1 (0 表示不自动启动)
#   INSTALL_ZSH=1 (0 跳过 zsh 栈)  ZSH_THEME_NAME=ys  ZSH_PLUGINS="git z zsh-syntax-highlighting zsh-autosuggestions"
# ============================================================
set -euo pipefail

# ---------- 可配置变量 ----------
GHOSTTY_THEME="${GHOSTTY_THEME:-Dracula}"
ZELLIJ_THEME="${ZELLIJ_THEME:-dracula}"
FONT_FAMILY="${FONT_FAMILY:-JetBrainsMono Nerd Font Mono}"
FONT_SIZE="${FONT_SIZE:-14}"
ZELLIJ_AUTOSTART="${ZELLIJ_AUTOSTART:-1}"
INSTALL_ZSH="${INSTALL_ZSH:-1}"              # 1=安装 zsh 栈(zsh/oh-my-zsh/插件), 0=跳过
ZSH_THEME_NAME="${ZSH_THEME_NAME:-ys}"
ZSH_PLUGINS="${ZSH_PLUGINS:-git z zsh-syntax-highlighting zsh-autosuggestions}"

# ---------- 路径 ----------
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
GHOSTTY_CONFIG="$CONFIG_DIR/ghostty/config"
ZELLIJ_CONFIG="$CONFIG_DIR/zellij/config.kdl"
ZSHRC="$HOME/.zshrc"
ZELLIJ_MARKER="# ---- zellij autostart (setup-dev-terminal.sh) ----"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { printf "${GREEN}[✓]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[!]${NC} %s\n" "$*"; }
die()  { printf "${YELLOW}[✗]${NC} %s\n" "$*"; exit 1; }

# ---------- 前置检查 ----------
[[ "$(uname -s)" == "Darwin" ]] || die "仅支持 macOS"
BREW="$(command -v brew || true)"
[[ -n "$BREW" ]] || die "未找到 Homebrew, 请先安装: https://brew.sh"
BREW_BIN="$(dirname "$BREW")"

# ---------- 1. 安装软件 ----------
install_formula() { # brew formula (zellij)
  local name="$1"
  if brew list --versions "$name" >/dev/null 2>&1; then
    info "$name 已安装 ($(brew list --versions "$name"))"
  else
    warn "安装 $name ..."
    if brew install "$name" >/dev/null 2>&1; then
      info "$name 安装完成"
    else
      warn "$name 安装失败, 请手动运行: brew install $name"
    fi
  fi
}

install_cask() { # brew cask (ghostty / 字体)
  local name="$1"
  if brew list --cask --versions "$name" >/dev/null 2>&1; then
    info "$name 已安装"
  else
    warn "安装 $name ..."
    if brew install --cask "$name" >/dev/null 2>&1; then
      info "$name 安装完成"
    else
      warn "$name 安装失败, 请手动运行: brew install --cask $name"
    fi
  fi
}

install_cask ghostty
install_formula zellij
install_cask font-jetbrains-mono-nerd-font

# ---------- 1.5 zsh 栈 (zsh + oh-my-zsh + 插件) ----------
# 依据: https://github.com/ohmyzsh/ohmyzsh/wiki/Installing-ZSH
install_zsh_stack() {
  install_formula zsh
  install_formula curl
  install_formula git

  # oh-my-zsh (--unattended: 非交互, 不修改默认 shell)
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    info "oh-my-zsh 已安装, 跳过"
  else
    warn "安装 oh-my-zsh ..."
    if sh -c "$(curl -fsSL https://install.ohmyz.sh)" "" --unattended >/dev/null 2>&1; then
      info "oh-my-zsh 安装完成"
    else
      warn "oh-my-zsh 安装失败, 请检查网络后重试 https://ohmyz.sh"
    fi
  fi

  # 插件 (zsh-syntax-highlighting / zsh-autosuggestions)
  local custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  mkdir -p "$custom/plugins"
  for p in $ZSH_PLUGINS; do
    case "$p" in
      zsh-syntax-highlighting) repo="https://github.com/zsh-users/zsh-syntax-highlighting" ;;
      zsh-autosuggestions)     repo="https://github.com/zsh-users/zsh-autosuggestions" ;;
      *) continue ;;
    esac
    if [[ -d "$custom/plugins/$p" ]]; then
      info "插件 $p 已存在, 跳过"
    else
      if git clone -q --depth 1 "$repo" "$custom/plugins/$p"; then
        info "插件 $p 安装完成"
      else
        warn "插件 $p 安装失败, 请检查网络"
      fi
    fi
  done

  # .zshrc: 设置 ZSH_THEME + 启用插件 (幂等, 修改前备份)
  configure_zshrc
}

configure_zshrc() {
  [[ -f "$HOME/.zshrc" ]] || touch "$HOME/.zshrc"
  local before new
  before=$(cat "$HOME/.zshrc")
  new=$(python3 - "$ZSH_THEME_NAME" "$ZSH_PLUGINS" <<'PYEOF'
import os, sys
theme, plugins_str = sys.argv[1], sys.argv[2].split()
path = os.path.expanduser('~/.zshrc')
lines = open(path).read().splitlines()
out, theme_done, plugins_done = [], False, False
for ln in lines:
    s = ln.strip()
    if s.startswith('ZSH_THEME='):
        out.append(f'ZSH_THEME="{theme}"')
        theme_done = True
        continue
    if s.startswith('plugins=(') and ')' in s:
        cur = s[len('plugins=('):s.rindex(')')].split()
        merged = []
        for p in cur + plugins_str:
            if p and p not in merged:
                merged.append(p)
        out.append('plugins=(' + ' '.join(merged) + ')')
        plugins_done = True
        continue
    out.append(ln)
if not theme_done:
    out.append(f'ZSH_THEME="{theme}"')
if not plugins_done:
    out.append('plugins=(' + ' '.join(plugins_str) + ')')
print('\n'.join(out))
PYEOF
)
  if [[ "$before" == "$new" ]]; then
    info ".zshrc 主题/插件已配置, 跳过"
  else
    cp "$HOME/.zshrc" "$HOME/.zshrc.bak.$(date +%s)"
    printf '%s\n' "$new" > "$HOME/.zshrc"
    warn "已备份旧 .zshrc, 写入 ZSH_THEME=$ZSH_THEME_NAME + plugins=($ZSH_PLUGINS)"
  fi
}

if [[ "$INSTALL_ZSH" == "1" ]]; then
  install_zsh_stack
fi

# ---------- 2. ghostty CLI 链接到 brew bin ----------
GHOSTTY_APP="/Applications/Ghostty.app/Contents/MacOS/ghostty"
if [[ -x "$GHOSTTY_APP" ]]; then
  if [[ ! -e "$BREW_BIN/ghostty" ]]; then
    ln -sf "$GHOSTTY_APP" "$BREW_BIN/ghostty"
    info "ghostty CLI 已链接到 $BREW_BIN/ghostty"
  else
    info "ghostty CLI 已存在"
  fi
else
  warn "未找到 Ghostty.app, 跳过 CLI 链接"
fi

# ---------- 3. 写配置文件 (相同内容跳过, 不同则备份后覆盖) ----------
write_if_changed() {
  # 注意: $(cat ...) 与 $(cat <<EOF ...) 都会剥离尾随换行, 两侧一致才能幂等
  local file="$1" content="$2"
  mkdir -p "$(dirname "$file")"
  if [[ -f "$file" ]] && [[ "$(cat "$file")" == "$content" ]]; then
    info "配置已存在, 跳过: $file"
  else
    if [[ -f "$file" ]]; then
      local bak="$file.bak.$(date +%s)"
      cp "$file" "$bak"
      warn "备份旧配置: $bak"
    fi
    printf '%s\n' "$content" > "$file"
    info "写入配置: $file"
  fi
}

write_if_changed "$GHOSTTY_CONFIG" "$(cat <<EOF
# ============ Ghostty Config ============
font-family = "$FONT_FAMILY"
font-size = $FONT_SIZE
font-thicken = true

theme = "$GHOSTTY_THEME"
window-theme = "dark"

window-padding-x = 10
window-padding-y = 10
background-opacity = 1
macos-titlebar-style = hidden
macos-option-as-alt = true

scrollback-limit = 10000
mouse-hide-while-typing = true
confirm-close-surface = false
copy-on-select = true
shell-integration = "zsh"
EOF
)"

write_if_changed "$ZELLIJ_CONFIG" "$(cat <<EOF
// ============ Zellij Config ============
theme "$ZELLIJ_THEME"
default_shell "zsh"
scroll_buffer_size 10000
mouse_mode true
pane_frames true
EOF
)"

# ---------- 4. zshrc 追加 zellij 自动启动 (幂等) ----------
ZSHRC_BLOCK=$(cat <<'EOF'
# ---- zellij autostart (setup-dev-terminal.sh) ----
export ZELLIJ_AUTOSTART=1
if [[ -z "$ZELLIJ" && "$ZELLIJ_AUTOSTART" == "1" && "$TERM_PROGRAM" == "ghostty" && $- == *i* ]]; then
  command -v zellij >/dev/null 2>&1 && exec zellij attach --create
fi
EOF
)
ZSHRC_BLOCK="${ZSHRC_BLOCK//ZELLIJ_AUTOSTART=1/ZELLIJ_AUTOSTART=$ZELLIJ_AUTOSTART}"
if grep -qF "$ZELLIJ_MARKER" "$ZSHRC" 2>/dev/null; then
  info "zshrc 已包含 zellij autostart, 跳过"
else
  printf '\n%s\n' "$ZSHRC_BLOCK" >> "$ZSHRC"
  info "已追加 zellij autostart 到 $ZSHRC"
fi

# ---------- 5. 验证 ----------
if "$BREW_BIN/ghostty" +validate-config >/dev/null 2>&1; then
  info "Ghostty 配置校验通过"
else
  warn "Ghostty 配置校验失败, 请手动检查 $GHOSTTY_CONFIG"
fi

echo
info "全部完成! 打开 Ghostty 即自动进入 zellij (Spotlight 搜 Ghostty)"
info "退出 zellij: Ctrl+o 然后 d(分离)/x(退出)"
info "关闭自动启动: 改 $ZSHRC 中 ZELLIJ_AUTOSTART=0"
info "zsh 插件需新开终端生效; 若默认 shell 仍是旧 zsh, 可运行: chsh -s \$(which zsh)"
