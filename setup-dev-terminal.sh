#!/usr/bin/env bash
# ============================================================
# 开发终端一键安装脚本 (macOS + Homebrew)
#
# 安装: Ghostty + zellij + JetBrainsMono Nerd Font + zsh 栈 + 开发工具(uv/bun/oh-my-pi/nvm+node)
# 配置: Ghostty 字体/主题 + zellij 主题 + zshrc(zellij 自动启动 + oh-my-zsh 主题/插件)
#
# 用法:   bash setup-dev-terminal.sh           # 交互式: 复选框选择要安装的组件
#         SKIP_INTERACTIVE=1 bash ...            # 跳过交互, 用环境变量配置
# 幂等:   可重复运行, 已装的跳过, 配置相同不覆盖, zshrc 不重复追加
# 环境变量可覆盖 (非交互模式或作为默认值):
#   GHOSTTY_THEME=Dracula  ZELLIJ_THEME=dracula  FONT_FAMILY="JetBrainsMono Nerd Font Mono"
#   FONT_SIZE=14  ZELLIJ_AUTOSTART=1 (0 表示不自动启动)
#   INSTALL_GHOSTTY/INSTALL_ZELLIJ/INSTALL_FONT/INSTALL_ZSH=1 (0 跳过对应组件)
#   INSTALL_ZSH=1 (0 跳过 zsh 栈)  ZSH_THEME_NAME=ys  ZSH_PLUGINS="git z zsh-syntax-highlighting zsh-autosuggestions"
#   INSTALL_DEVTOOLS=1 (0 跳过 uv/bun/oh-my-pi/nvm)  单项可用 INSTALL_UV/INSTALL_BUN/INSTALL_OMP/INSTALL_NVM=0 关闭
#   NODE_VERSION=24 (nvm 安装的 node 版本)  NVM_NODEJS_ORG_MIRROR= (可选: 国内镜像加速, 如 https://npmmirror.com/mirrors/node/)
# ============================================================
set -euo pipefail

# ---------- 可配置变量 ----------
GHOSTTY_THEME="${GHOSTTY_THEME:-Dracula}"
ZELLIJ_THEME="${ZELLIJ_THEME:-dracula}"
FONT_FAMILY="${FONT_FAMILY:-JetBrainsMono Nerd Font Mono}"
FONT_SIZE="${FONT_SIZE:-14}"
ZELLIJ_AUTOSTART="${ZELLIJ_AUTOSTART:-1}"
INSTALL_ZSH="${INSTALL_ZSH:-1}"              # 1=安装 zsh 栈(zsh/oh-my-zsh/插件), 0=跳过
INSTALL_GHOSTTY="${INSTALL_GHOSTTY:-1}"      # 1=安装 Ghostty
INSTALL_ZELLIJ="${INSTALL_ZELLIJ:-1}"        # 1=安装 zellij
INSTALL_FONT="${INSTALL_FONT:-1}"            # 1=安装 JetBrainsMono Nerd Font
ZSH_THEME_NAME="${ZSH_THEME_NAME:-ys}"
ZSH_PLUGINS="${ZSH_PLUGINS:-git z zsh-syntax-highlighting zsh-autosuggestions}"

# ---- 开发工具 (uv / bun / oh-my-pi(omp) / nvm+node) ----
INSTALL_DEVTOOLS="${INSTALL_DEVTOOLS:-1}"       # 总开关
INSTALL_UV="${INSTALL_UV:-1}"
INSTALL_BUN="${INSTALL_BUN:-1}"
INSTALL_OMP="${INSTALL_OMP:-1}"                  # oh-my-pi (@oh-my-pi/pi-coding-agent, bin: omp)
INSTALL_NVM="${INSTALL_NVM:-1}"
NODE_VERSION="${NODE_VERSION:-24}"
NVM_NODEJS_ORG_MIRROR="${NVM_NODEJS_ORG_MIRROR:-}"
[[ -n "$NVM_NODEJS_ORG_MIRROR" ]] && export NVM_NODEJS_ORG_MIRROR
FORCE_BREW_TOOLS="${FORCE_BREW_TOOLS:-0}"  # 1=强制用 brew 安装 zsh/curl/git (默认系统自带则跳过)
INSTALL_BREW="${INSTALL_BREW:-1}"          # 1=未检测到 brew 时自动安装官方脚本, 0=直接报错

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
if [[ -z "$BREW" ]]; then
  if [[ "$INSTALL_BREW" != "1" ]]; then
    die "未找到 Homebrew, 请先安装: https://brew.sh (或设 INSTALL_BREW=1 自动安装)"
  fi
  warn "未检测到 Homebrew, 正在自动安装 (官方脚本, 可能需 sudo 密码) ..."
  if [[ ! -t 0 ]] || [[ "${SKIP_INTERACTIVE:-0}" == "1" ]]; then
    warn "非交互模式: 自动跳过确认 (NONINTERACTIVE=1), 但 sudo 仍需可用"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
      || die "Homebrew 安装失败, 请手动运行官方命令: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
      || die "Homebrew 安装失败, 请手动运行官方命令: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  fi
  # 安装后定位 brew (Apple Silicon: /opt/homebrew; Intel: /usr/local)
  if [[ -x /opt/homebrew/bin/brew ]]; then
    BREW=/opt/homebrew/bin/brew
  elif [[ -x /usr/local/bin/brew ]]; then
    BREW=/usr/local/bin/brew
  else
    die "brew 安装后未找到, 请手动运行官方安装命令"
  fi
  info "Homebrew 安装完成 ($BREW)"
fi
BREW_BIN="$(dirname "$BREW")"

# ---------- 交互式复选框选择 (仅 TTY; SKIP_INTERACTIVE=1 或管道输入时跳过) ----------
# 纯 bash + ANSI 转义实现, 零依赖, 兼容 bash 3.2 (macOS 系统自带)
MENU_OPTIONS=()
MENU_INIT=()
MENU_SEL=()
MENU_CUR=0
MENU_RESULT=()
C_RESET='\033[0m'; C_GREEN='\033[32m'; C_CYAN='\033[36m'; C_BOLD='\033[1m'; C_DIM='\033[2m'

menu_cleanup() { printf '\033[?25h\033[0m'; stty echo icanon 2>/dev/null; }

trap menu_cleanup EXIT INT TERM

menu_is_sel() { local i; for i in ${MENU_SEL[@]+"${MENU_SEL[@]}"}; do [[ "$i" == "$1" ]] && return 0; done; return 1; }

menu_draw() {
  printf '\033[H'
  printf "${C_BOLD}${C_CYAN}安装项 (j/k或↑↓移动 · 空格勾选 · 回车确认 · q退出)${C_RESET}\n"
  printf "${C_DIM}────────────────────────────────────────${C_RESET}\n"
  for i in "${!MENU_OPTIONS[@]}"; do
    local desc="${MENU_OPTIONS[$i]#*|}" mark=" "
    menu_is_sel "$i" && mark="x"
    if [[ $i -eq $MENU_CUR ]]; then
      printf "${C_GREEN}▶ [%s] %s${C_RESET}\n" "$mark" "$desc"
    else
      printf "  [%s] %s\n" "$mark" "$desc"
    fi
  done
  printf "${C_DIM}────────────────────────────────────────${C_RESET}\n"
}

checkbox_menu() {
  MENU_CUR=0
  MENU_SEL=()
  local i key rest
  for i in ${MENU_INIT[@]+"${MENU_INIT[@]}"}; do menu_is_sel "$i" || MENU_SEL+=("$i"); done
  printf '\033[2J\033[?25l'
  while true; do
    menu_draw
    IFS= read -rsn1 key || true
    case "$key" in
      $'\x1b')
        read -rsn2 -t 1 rest || true   # bash 3.2 仅支持整数超时; 方向键序列瞬间到达, 无感
        case "$rest" in
          '[A') ((MENU_CUR > 0)) && ((MENU_CUR--)) ;;
          '[B') ((MENU_CUR < ${#MENU_OPTIONS[@]}-1)) && ((MENU_CUR++)) ;;
        esac
        ;;
      'j'|'J') ((MENU_CUR < ${#MENU_OPTIONS[@]}-1)) && ((MENU_CUR++)) ;;
      'k'|'K') ((MENU_CUR > 0)) && ((MENU_CUR--)) ;;
      ' ')  # 空格: 切换勾选
        if menu_is_sel "$MENU_CUR"; then
          local -a tmp=()
          for i in ${MENU_SEL[@]+"${MENU_SEL[@]}"}; do [[ "$i" != "$MENU_CUR" ]] && tmp+=("$i"); done
          MENU_SEL=("${tmp[@]}")
        else
          MENU_SEL+=("$MENU_CUR")
        fi
        ;;
      $'\n'|'') break ;;
      'q'|'Q') printf '\033[?25h\n'; exit 1 ;;
    esac
  done
  MENU_RESULT=(${MENU_SEL[@]+"${MENU_SEL[@]}"})
  printf '\033[?25h\n'
}

run_interactive() {
  MENU_OPTIONS=(
    "ghostty|Ghostty 终端 (GPU 渲染)"
    "zellij|zellij 终端复用 (多窗口/pane)"
    "font|JetBrainsMono Nerd Font (图标字体)"
    "zsh|zsh 栈: zsh + oh-my-zsh + 插件"
    "uv|uv Python 包管理器"
    "bun|bun JS 运行时/包管理器"
    "omp|oh-my-pi (omp) 开发助手"
    "nvm|nvm + Node $NODE_VERSION"
  )
  MENU_INIT=()
  local i id
  for i in "${!MENU_OPTIONS[@]}"; do MENU_INIT+=("$i"); done
  checkbox_menu
  # 勾选结果覆盖安装开关 (全默认关, 勾选的开启)
  INSTALL_GHOSTTY=0; INSTALL_ZELLIJ=0; INSTALL_FONT=0
  INSTALL_ZSH=0; INSTALL_UV=0; INSTALL_BUN=0; INSTALL_OMP=0; INSTALL_NVM=0
  for i in ${MENU_RESULT[@]+"${MENU_RESULT[@]}"}; do
    id="${MENU_OPTIONS[$i]%%|*}"
    case "$id" in
      ghostty) INSTALL_GHOSTTY=1 ;;
      zellij)  INSTALL_ZELLIJ=1 ;;
      font)    INSTALL_FONT=1 ;;
      zsh)     INSTALL_ZSH=1 ;;
      uv)      INSTALL_UV=1 ;;
      bun)     INSTALL_BUN=1 ;;
      omp)     INSTALL_OMP=1 ;;
      nvm)     INSTALL_NVM=1 ;;
    esac
  done
  echo
}

if [[ -t 0 ]] && [[ "${SKIP_INTERACTIVE:-0}" != "1" ]]; then
  run_interactive
else
  info "非交互模式: 使用环境变量配置 (交互模式: 直接运行 bash setup-dev-terminal.sh)"
fi

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

install_util() { # 系统自带工具 (zsh/curl/git): 命令已存在即跳过, 避免无谓覆盖系统版本
  # macOS 自带 /bin/zsh /usr/bin/curl /usr/bin/git, 新机器无需重复安装 brew 版
  # 检测: command -v (POSIX 内建, 不 fork 外部进程) 优先; which (通用, 输出路径) 兜底
  # 两者都返回实际路径, 如 /usr/bin/curl
  # FORCE_BREW_TOOLS=1 可强制安装 brew 版
  local name="$1" found=""
  if [[ "${FORCE_BREW_TOOLS:-0}" == "1" ]]; then
    install_formula "$name"
    return
  fi
  if command -v "$name" >/dev/null 2>&1; then
    found="$(command -v "$name" 2>/dev/null)"
  elif which "$name" >/dev/null 2>&1; then
    found="$(which "$name" 2>/dev/null)"
  fi
  if [[ -n "$found" ]]; then
    info "$name 已存在 ($found), 跳过 brew 安装"
  elif brew list --versions "$name" >/dev/null 2>&1; then
    info "$name 已安装 (brew)"
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

[[ "$INSTALL_GHOSTTY" == "1" ]] && install_cask ghostty
[[ "$INSTALL_ZELLIJ" == "1" ]] && install_formula zellij
[[ "$INSTALL_FONT" == "1" ]] && install_cask font-jetbrains-mono-nerd-font

# ---------- 1.5 zsh 栈 (zsh + oh-my-zsh + 插件) ----------
# 依据: https://github.com/ohmyzsh/ohmyzsh/wiki/Installing-ZSH
install_zsh_stack() {
  install_util zsh
  install_util curl
  install_util git

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

# ---------- 1.6 开发工具 (uv / bun / oh-my-pi(omp) / nvm+node) ----------
install_devtools() {
  # uv (Python 包管理器)
  if [[ "$INSTALL_UV" == "1" ]]; then
    if command -v uv >/dev/null 2>&1; then
      info "uv 已安装 ($(uv --version 2>/dev/null | head -1))"
    else
      warn "安装 uv ..."
      if curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1; then
        info "uv 安装完成"
      else
        warn "uv 安装失败, 请手动运行: curl -LsSf https://astral.sh/uv/install.sh | sh"
      fi
    fi
  fi

  # bun (JS 运行时/包管理器)
  if [[ "$INSTALL_BUN" == "1" ]]; then
    if command -v bun >/dev/null 2>&1 || [[ -x "$HOME/.bun/bin/bun" ]]; then
      local bver
      bver=$("$HOME/.bun/bin/bun" --version 2>/dev/null || bun --version 2>/dev/null)
      info "bun 已安装 ($bver)"
    else
      warn "安装 bun ..."
      if curl -fsSL https://bun.com/install | bash >/dev/null 2>&1; then
        info "bun 安装完成"
      else
        warn "bun 安装失败, 请手动运行: curl -fsSL https://bun.com/install | bash"
      fi
    fi
  fi

  # oh-my-pi (@oh-my-pi/pi-coding-agent, bin: omp)
  if [[ "$INSTALL_OMP" == "1" ]]; then
    if command -v omp >/dev/null 2>&1 || [[ -x "$HOME/.bun/bin/omp" ]]; then
      info "oh-my-pi (omp) 已安装"
    else
      warn "安装 oh-my-pi (omp) ..."
      if curl -fsSL https://omp.sh/install | sh >/dev/null 2>&1; then
        info "oh-my-pi (omp) 安装完成, 运行 omp 开始使用"
      else
        warn "oh-my-pi (omp) 安装失败, 请手动运行: curl -fsSL https://omp.sh/install | sh"
      fi
    fi
  fi

  # nvm + node (nvm 是 shell 函数, 需 source 后调用)
  if [[ "$INSTALL_NVM" == "1" ]]; then
    if [[ ! -d "$HOME/.nvm" ]]; then
      warn "安装 nvm ..."
      if curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.6/install.sh | bash >/dev/null 2>&1; then
        info "nvm 安装完成"
      else
        warn "nvm 安装失败, 请手动运行: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.6/install.sh | bash"
      fi
    else
      info "nvm 已安装, 跳过"
    fi

    if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
      . "$HOME/.nvm/nvm.sh"
      if ls "$HOME/.nvm/versions/node/" 2>/dev/null | grep -q "^v$NODE_VERSION\."; then
        info "node $NODE_VERSION 已安装, 跳过"
      else
        warn "nvm install $NODE_VERSION ..."
        if nvm install "$NODE_VERSION" >/dev/null 2>&1; then
          info "node $NODE_VERSION 安装完成 (新终端中执行 nvm use $NODE_VERSION 生效)"
        else
          warn "node $NODE_VERSION 安装失败, 请手动运行: nvm install $NODE_VERSION"
        fi
      fi
    fi
  fi
}

if [[ "$INSTALL_DEVTOOLS" == "1" ]]; then
  install_devtools
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

if [[ "$INSTALL_GHOSTTY" == "1" ]]; then
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
fi

if [[ "$INSTALL_ZELLIJ" == "1" ]]; then
write_if_changed "$ZELLIJ_CONFIG" "$(cat <<EOF
// ============ Zellij Config ============
theme "$ZELLIJ_THEME"
default_shell "zsh"
scroll_buffer_size 10000
mouse_mode true
pane_frames true
EOF
)"
fi

# ---------- 4. zshrc 追加 zellij 自动启动 (幂等) ----------
if [[ "$INSTALL_ZELLIJ" == "1" && "$ZELLIJ_AUTOSTART" == "1" ]]; then
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
fi

# ---------- 5. 验证 ----------
if [[ "$INSTALL_GHOSTTY" == "1" ]]; then
  if "$BREW_BIN/ghostty" +validate-config >/dev/null 2>&1; then
    info "Ghostty 配置校验通过"
  else
    warn "Ghostty 配置校验失败, 请手动检查 $GHOSTTY_CONFIG"
  fi
fi

echo
info "全部完成! 打开 Ghostty 即自动进入 zellij (Spotlight 搜 Ghostty)"
info "退出 zellij: Ctrl+o 然后 d(分离)/x(退出)"
info "关闭自动启动: 改 $ZSHRC 中 ZELLIJ_AUTOSTART=0"
info "zsh 插件需新开终端生效; 若默认 shell 仍是旧 zsh, 可运行: chsh -s \$(which zsh)"
info "nvm 环境在新终端生效 (nvm use $NODE_VERSION); oh-my-pi (omp) 运行 omp 开始使用"
