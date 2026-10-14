#!/usr/bin/env bash
# ============================================================
# 开发终端一键安装脚本 (macOS + Linux)
#
# 安装: Ghostty + herdr + JetBrainsMono Nerd Font + zsh 栈 + 开发工具(uv/bun/oh-my-pi/nvm+node)
# 配置: Ghostty 字体/主题 + herdr 主题 + zshrc(herdr 自动启动 + oh-my-zsh 主题/插件)
#
# 平台: macOS (Homebrew) / Linux (apt/dnf/pacman/zypper/apk/emerge/xbps/nix)
#       不支持的组件会自动灰显且不可勾选 (如无图形界面时的 Ghostty)
#
# 用法:   bash setup-dev-terminal.sh           # 交互式: 复选框选择要安装的组件
#         SKIP_INTERACTIVE=1 bash ...            # 跳过交互, 用环境变量配置
# 幂等:   可重复运行, 已装的跳过, 配置相同不覆盖, zshrc 不重复追加
# 环境变量可覆盖 (非交互模式或作为默认值):
#   GHOSTTY_THEME=Dracula  HERDR_THEME=dracula  FONT_FAMILY="JetBrainsMono Nerd Font Mono"
#   FONT_SIZE=14  HERDR_AUTOSTART=1 (0 表示不自动启动)
#   INSTALL_GHOSTTY/INSTALL_HERDR/INSTALL_FONT/INSTALL_ZSH=1 (0 跳过对应组件)
#   INSTALL_SKILLS=1 (0 跳过 agent skills 安装; 需要 node/npx)
#     SKILL_PACKAGES 见下方: "<源>|<skill 名>", skill 名写 "*" 表示装该源全部
#   INSTALL_ZSH=1 (0 跳过 zsh 栈)  ZSH_THEME_NAME=ys  ZSH_PLUGINS="git z zsh-syntax-highlighting zsh-autosuggestions"
#   INSTALL_DEVTOOLS=1 (0 跳过 uv/bun/oh-my-pi/nvm)  单项可用 INSTALL_UV/INSTALL_BUN/INSTALL_OMP/INSTALL_NVM=0 关闭
#   NODE_VERSION=24 (nvm 安装的 node 版本)  NVM_NODEJS_ORG_MIRROR= (可选: 国内镜像加速, 如 https://npmmirror.com/mirrors/node/)
#   FORCE_GUI=1 (无 DISPLAY/WAYLAND_DISPLAY 时仍允许装 Ghostty, 如 WSL/远程 X)
# ============================================================
set -euo pipefail

# 原始 PATH (在脚本自己修改 PATH 之前保存; 用于判断 ~/.local/bin 是否已可用)
ORIG_PATH="$PATH"

# ---------- 输出助手 (需在平台探测之前定义, detect_platform 会用到 die) ----------
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { printf "${GREEN}[✓]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[!]${NC} %s\n" "$*"; }
die()  { printf "${YELLOW}[✗]${NC} %s\n" "$*"; exit 1; }

# 点分版本比较: $1 >= $2 返回 0 (兼容 bash 3.2, 无外部依赖)
# 注意: 供 capability() 等早期调用; 1.7 节的 bun 版本检查也复用它
ver_ge() {
  local IFS=. i v1="$1" v2="$2"
  set -- $v1; local -a a=("$@")
  set -- $v2; local -a b=("$@")
  for i in 0 1 2; do
    (( ${a[$i]:-0} > ${b[$i]:-0} )) && return 0
    (( ${a[$i]:-0} < ${b[$i]:-0} )) && return 1
  done
  return 0
}

# ---------- 平台探测 ----------
OS_KIND="$(uname -s)"                        # Darwin | Linux
ARCH_RAW="$(uname -m)"
DISTRO_ID=""; DISTRO_LIKE=""; DISTRO_PRETTY=""; DISTRO_VERSION=""
PKG_MGR=""                                   # brew|apt|dnf|pacman|zypper|apk|emerge|xbps|nix
HAS_GUI=0                                    # Ghostty 需要图形界面
IS_MACOS=0; IS_LINUX=0

detect_platform() {
  case "$OS_KIND" in
    Darwin) IS_MACOS=1 ;;
    Linux)  IS_LINUX=1 ;;
    *)      die "仅支持 macOS 与 Linux (当前: $OS_KIND)" ;;
  esac
  if [[ "$IS_LINUX" == "1" && -r /etc/os-release ]]; then
    DISTRO_ID="$(. /etc/os-release 2>/dev/null; echo "${ID:-}")"
    DISTRO_LIKE="$(. /etc/os-release 2>/dev/null; echo "${ID_LIKE:-}")"
    DISTRO_PRETTY="$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-${NAME:-}}")"
    DISTRO_VERSION="$(. /etc/os-release 2>/dev/null; echo "${VERSION_ID:-}")"
  fi
  if [[ "$IS_MACOS" == "1" ]]; then
    PKG_MGR="brew"
  else
    local c
    for c in apt-get dnf pacman zypper apk emerge xbps-install nix; do
      if command -v "$c" >/dev/null 2>&1; then
        case "$c" in
          apt-get)      PKG_MGR="apt" ;;
          xbps-install) PKG_MGR="xbps" ;;
          *)            PKG_MGR="$c" ;;
        esac
        break
      fi
    done
  fi
  # 图形界面探测: Ghostty 是 GUI 程序, 无显示服务器时装了也用不了
  if [[ "$IS_MACOS" == "1" ]]; then
    HAS_GUI=1
  elif [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
    HAS_GUI=1
  fi
  [[ "${FORCE_GUI:-0}" == "1" ]] && HAS_GUI=1
  return 0
}
detect_platform

# ---------- 支持情况 (回显空=支持; 回显非空=不支持的原因) ----------
capability() {
  local id="$1"
  case "$id" in
    ghostty)
      if [[ "$IS_LINUX" == "1" ]]; then
        [[ "$HAS_GUI" == "1" ]] || { echo "需要图形界面 (无 DISPLAY/WAYLAND_DISPLAY)"; return; }
        case "$DISTRO_ID" in
          arch|manjaro|endeavouros|garuda|cachyos|artix|arcolinux) : ;;
          ubuntu)
            # 实测: 官方源仅 26.04+ 有 ghostty, 24.04/22.04 无
            if ! ver_ge "${DISTRO_VERSION:-0}" "26.04"; then
              echo "Ubuntu ${DISTRO_VERSION:-?} 官方源无 ghostty (需 26.04+ 或社区 .deb)"
              return
            fi ;;
          linuxmint|pop|elementary|zorin|kali) : ;;   # 走社区 .deb 路径
          debian) echo "Debian 官方源无 ghostty (需社区 .deb 或 AppImage)"; return ;;
          fedora|rhel|centos|rocky|almalinux|ol) : ;; # 走 COPR 提示路径
          opensuse*|sles|sled) : ;;
          alpine|gentoo|void|solus|nixos) : ;;
          *) echo "无预编译包 (${DISTRO_ID:-未知发行版})"; return ;;
        esac
      fi
      ;;
    herdr)
      case "$ARCH_RAW" in
        x86_64|amd64|aarch64|arm64) : ;;
        *) echo "herdr 无 $ARCH_RAW 预编译二进制"; return ;;
      esac
      ;;
    font)
      # 全平台可装: 有包用包, 没有则下载到 ~/.local/share/fonts
      : ;;
    zsh|uv|bun|omp|nvm|skills)
      case "$ARCH_RAW" in
        riscv64|ppc64le|s390x|i686|armv7l)
          [[ "$id" == "skills" || "$id" == "nvm" || "$id" == "zsh" ]] || { echo "无 $ARCH_RAW 预编译二进制"; return; }
          ;;
      esac
      ;;
  esac
}

# ---------- 包管理器封装 ----------
pkg_install() { # 安装一个系统包 (Linux); 返回非 0 表示失败
  local name="$1" sudo=""
  [[ "$(id -u)" != "0" ]] && sudo="sudo"
  case "$PKG_MGR" in
    apt)    $sudo apt-get install -y "$name" ;;
    dnf)    $sudo dnf install -y "$name" ;;
    pacman) $sudo pacman -S --noconfirm --needed "$name" ;;
    zypper) $sudo zypper -n install "$name" ;;
    apk)    $sudo apk add "$name" ;;
    emerge) $sudo emerge -av "$name" ;;
    xbps)   $sudo xbps-install -y "$name" ;;
    nix)    nix profile install "nixpkgs#$name" ;;
    *)      return 1 ;;
  esac
}

pkg_installed() { # 该包是否已装 (尽力而为; 不支持的包管理器返回 1)
  local name="$1"
  case "$PKG_MGR" in
    apt)    dpkg -s "$name" >/dev/null 2>&1 ;;
    dnf)    rpm -q "$name" >/dev/null 2>&1 ;;
    pacman) pacman -Qq "$name" >/dev/null 2>&1 ;;
    zypper) rpm -q "$name" >/dev/null 2>&1 ;;
    apk)    apk info -e "$name" >/dev/null 2>&1 ;;
    xbps)   xbps-query "$name" >/dev/null 2>&1 ;;
    nix)    nix profile list 2>/dev/null | grep -q "nixpkgs#$name" ;;
    *)      return 1 ;;
  esac
}

# ---------- 可配置变量 ----------
GHOSTTY_THEME="${GHOSTTY_THEME:-Dracula}"
HERDR_THEME="${HERDR_THEME:-dracula}"
FONT_FAMILY="${FONT_FAMILY:-JetBrainsMono Nerd Font Mono}"
FONT_SIZE="${FONT_SIZE:-14}"
HERDR_AUTOSTART="${HERDR_AUTOSTART:-1}"
INSTALL_ZSH="${INSTALL_ZSH:-1}"              # 1=安装 zsh 栈(zsh/oh-my-zsh/插件), 0=跳过
INSTALL_GHOSTTY="${INSTALL_GHOSTTY:-1}"      # 1=安装 Ghostty
INSTALL_HERDR="${INSTALL_HERDR:-1}"          # 1=安装 herdr
INSTALL_FONT="${INSTALL_FONT:-1}"            # 1=安装 JetBrainsMono Nerd Font
ZSH_THEME_NAME="${ZSH_THEME_NAME:-ys}"
ZSH_PLUGINS="${ZSH_PLUGINS:-git z zsh-syntax-highlighting zsh-autosuggestions}"

# ---- agent skills (npx skills, 安装到 ~/.agents/skills, 多数 agent 自动读取) ----
INSTALL_SKILLS="${INSTALL_SKILLS:-1}"           # 1=安装 agent skills (需要 node/npx), 0=跳过
SKILLS_DIR="$HOME/.agents/skills"
SKILLS_LOCK="$HOME/.agents/.skill-lock.json"
# 每个元素格式: "<源>|<skill 名>"  (源可为 owner/repo 或 git URL)
#   skill 名写 "*" 表示装该源全部 skill; 也可写空格分隔的多个名字, 只装指定的
# 注意: 同名 skill 会被后装的覆盖 (如 herdr 与 mattpocock 都有 triage)
SKILL_PACKAGES=(
  "herdrdev/herdr|herdr"
  "mattpocock/skills|code-review codebase-design diagnosing-bugs grilling grill-me grill-with-docs handoff implement improve-codebase-architecture prototype research tdd teach to-questionnaire to-spec to-tickets wait-what writing-for-agents"
  "vercel-labs/skills|find-skills"
  "jackwener/opencli|opencli-adapter-author opencli-autofix opencli-browser opencli-usage smart-search"
  "hkuds/cli-anything|cli-anything cli-hub-meta-skill cli-anything-audacity cli-anything-blender cli-anything-comfyui cli-anything-libreoffice cli-anything-mermaid cli-anything-musescore"
  "https://cnb.cool/cnb/skills/cnb-skill.git|cnb-api cnb-code-commit cnb-code-review cnb-docs cnb-npc-search cnb-pipeline cnb-repo-knowledge-base cnb-tapd-resource-fetcher cnb-text-path-converter cnb-upload-attachment"
  "https://cnb.cool/lzf.ai/utils/dmxapi-cli.git|cli-anything-dmxapi"
)

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
HERDR_CONFIG="$CONFIG_DIR/herdr/config.toml"
ZSHRC="$HOME/.zshrc"
HERDR_MARKER="# ---- herdr autostart (setup-dev-terminal.sh) ----"

# ---------- 前置检查: Homebrew (仅 macOS 需要; Linux 用发行版包管理器) ----------
BREW=""
if [[ "$IS_MACOS" == "1" ]]; then
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
fi
BREW_BIN=""
[[ -n "$BREW" ]] && BREW_BIN="$(dirname "$BREW")"

# ---------- 交互式复选框选择 (仅 TTY; SKIP_INTERACTIVE=1 或管道输入时跳过) ----------
# 纯 bash + ANSI 转义实现, 零依赖, 兼容 bash 3.2 (macOS 系统自带)
MENU_OPTIONS=()
MENU_INIT=()
MENU_SEL=()
MENU_DISABLED=()   # 每项: 空=可选; 非空=不可选的原因 (灰显)
MENU_CUR=0
MENU_RESULT=()
C_RESET='\033[0m'; C_GREEN='\033[32m'; C_CYAN='\033[36m'; C_BOLD='\033[1m'; C_DIM='\033[2m'

menu_cleanup() { printf '\033[?25h\033[0m'; stty echo icanon 2>/dev/null || true; }

trap menu_cleanup EXIT INT TERM

menu_is_sel() { local i; for i in ${MENU_SEL[@]+"${MENU_SEL[@]}"}; do [[ "$i" == "$1" ]] && return 0; done; return 1; }

menu_is_disabled() { [[ -n "${MENU_DISABLED[$1]:-}" ]]; }

menu_move() { # 移动光标 (允许停在不可用项上, 以便显示不可用原因)
  local dir="$1" next=$((MENU_CUR + dir)) last=$((${#MENU_OPTIONS[@]} - 1))
  (( next < 0 || next > last )) && return 0
  MENU_CUR=$next
}

menu_draw() {
  printf '\033[H'
  printf "${C_BOLD}${C_CYAN}安装项 (j/k或↑↓移动 · 空格勾选 · 回车确认 · q退出)${C_RESET}\n"
  printf "${C_DIM}────────────────────────────────────────${C_RESET}\n"
  local i desc mark reason
  for i in "${!MENU_OPTIONS[@]}"; do
    desc="${MENU_OPTIONS[$i]#*|}"; mark=" "; reason="${MENU_DISABLED[$i]:-}"
    menu_is_sel "$i" && mark="x"
    if [[ -n "$reason" ]]; then
      # 灰色 = 不支持; 光标停在此项时额外显示原因
      if [[ $i -eq $MENU_CUR ]]; then
        printf "${C_DIM}▶ [-] %s  (不可用: %s)${C_RESET}\n" "$desc" "$reason"
      else
        printf "${C_DIM}  [-] %s${C_RESET}\n" "$desc"
      fi
    elif [[ $i -eq $MENU_CUR ]]; then
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
          '[A') menu_move -1 ;;
          '[B') menu_move 1 ;;
        esac
        ;;
      'j'|'J') menu_move 1 ;;
      'k'|'K') menu_move -1 ;;
      ' ')  # 空格: 切换勾选 (不支持项直接忽略)
        if menu_is_disabled "$MENU_CUR"; then
          :
        elif menu_is_sel "$MENU_CUR"; then
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
    "herdr|herdr 终端复用 (多窗口/pane)"
    "font|JetBrainsMono Nerd Font (图标字体)"
    "zsh|zsh 栈: zsh + oh-my-zsh + 插件"
    "uv|uv Python 包管理器"
    "bun|bun JS 运行时/包管理器"
    "omp|oh-my-pi (omp) 开发助手"
    "nvm|nvm + Node $NODE_VERSION"
    "skills|agent skills (npx skills, 需 node)"
  )
  MENU_INIT=()
  MENU_DISABLED=()
  local i id reason
  for i in "${!MENU_OPTIONS[@]}"; do
    id="${MENU_OPTIONS[$i]%%|*}"
    reason="$(capability "$id")"
    MENU_DISABLED+=("$reason")
    [[ -n "$reason" ]] && continue      # 不支持的不预勾选
    MENU_INIT+=("$i")
  done
  checkbox_menu
  # 勾选结果覆盖安装开关 (全默认关, 勾选的开启)
  INSTALL_GHOSTTY=0; INSTALL_HERDR=0; INSTALL_FONT=0
  INSTALL_ZSH=0; INSTALL_UV=0; INSTALL_BUN=0; INSTALL_OMP=0; INSTALL_NVM=0
  INSTALL_SKILLS=0
  for i in ${MENU_RESULT[@]+"${MENU_RESULT[@]}"}; do
    id="${MENU_OPTIONS[$i]%%|*}"
    case "$id" in
      ghostty) INSTALL_GHOSTTY=1 ;;
      herdr)   INSTALL_HERDR=1 ;;
      font)    INSTALL_FONT=1 ;;
      zsh)     INSTALL_ZSH=1 ;;
      uv)      INSTALL_UV=1 ;;
      bun)     INSTALL_BUN=1 ;;
      omp)     INSTALL_OMP=1 ;;
      nvm)     INSTALL_NVM=1 ;;
      skills)  INSTALL_SKILLS=1 ;;
    esac
  done
  echo
}

# 非交互模式: 把不支持的组件自动关掉, 避免静默失败
apply_capabilities() {
  local id var reason
  for id in ghostty herdr font zsh uv bun omp nvm skills; do
    reason="$(capability "$id")"
    [[ -z "$reason" ]] && continue
    case "$id" in
      ghostty) var=INSTALL_GHOSTTY ;; herdr) var=INSTALL_HERDR ;;
      font)    var=INSTALL_FONT    ;; zsh)   var=INSTALL_ZSH ;;
      uv)      var=INSTALL_UV      ;; bun)   var=INSTALL_BUN ;;
      omp)     var=INSTALL_OMP     ;; nvm)   var=INSTALL_NVM ;;
      skills)  var=INSTALL_SKILLS  ;;
    esac
    [[ "${!var}" == "1" ]] || continue
    printf -v "$var" '%s' 0
    warn "跳过 $id: $reason"
  done
}

if [[ -t 0 ]] && [[ "${SKIP_INTERACTIVE:-0}" != "1" ]]; then
  run_interactive
else
  info "非交互模式: 使用环境变量配置 (交互模式: 直接运行 bash setup-dev-terminal.sh)"
  apply_capabilities
fi

# ---------- 1. 安装软件 ----------
install_formula() { # 系统包 (macOS: brew formula; Linux: 发行版包管理器)
  local name="$1" pkg="${2:-$1}"
  if [[ "$IS_MACOS" == "1" ]]; then
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
    return
  fi
  if pkg_installed "$pkg"; then
    info "$pkg 已安装"
  elif pkg_install "$pkg" >/dev/null 2>&1; then
    info "$pkg 安装完成"
  else
    warn "$pkg 安装失败, 请手动安装 ($PKG_MGR: $pkg)"
  fi
}

install_ghostty() { # Ghostty 终端 (macOS: cask; Linux: 发行版包, 见 capability ghostty)
  if [[ "$IS_MACOS" == "1" ]]; then
    install_cask ghostty
    return
  fi
  local pkg=""
  case "$PKG_MGR" in
    pacman) pkg="ghostty" ;;
    apk)    pkg="ghostty" ;;
    emerge) pkg="ghostty" ;;
    xbps)   pkg="ghostty" ;;
    zypper) pkg="ghostty" ;;
    nix)    pkg="ghostty" ;;
    apt)    pkg="ghostty" ;;     # Ubuntu 26.04+ universe
    dnf)    pkg="" ;;            # Fedora 仅 COPR/Terra 第三方源, 不自动启用
    *)      pkg="" ;;
  esac
  if [[ -z "$pkg" ]]; then
    warn "Ghostty 在本发行版无官方包; 可选社区源:"
    case "$DISTRO_ID" in
      fedora|rhel|centos|rocky|almalinux|ol)
        warn "  dnf copr enable scottames/ghostty && dnf install ghostty" ;;
      debian|linuxmint|pop|elementary|zorin|kali)
        warn "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh)\"" ;;
      *)
        warn "  https://ghostty.org/docs/install/binary" ;;
    esac
    warn "  通用 AppImage: https://github.com/pkgforge-dev/ghostty-appimage/releases"
    return
  fi
  if command -v ghostty >/dev/null 2>&1 || pkg_installed "$pkg"; then
    info "ghostty 已安装"
  elif pkg_install "$pkg" >/dev/null 2>&1; then
    info "ghostty 安装完成"
  else
    warn "ghostty 安装失败, 请手动安装 ($PKG_MGR: $pkg)"
  fi
}

install_font() { # JetBrainsMono Nerd Font (全平台: 有包用包, 否则下载到用户字体目录)
  if [[ "$IS_MACOS" == "1" ]]; then
    install_cask font-jetbrains-mono-nerd-font
    return
  fi
  # Linux: 优先发行版包
  local pkg="" fonts_dir="$HOME/.local/share/fonts"
  case "$PKG_MGR" in
    pacman) pkg="ttf-jetbrains-mono-nerd" ;;
    apk)    pkg="font-jetbrains-mono-nerd" ;;
    apt)    pkg="fonts-nerd-symbols" ;;   # Debian/Ubuntu 无整包, 装符号字体兜底
    dnf)    pkg="" ;;
    *)      pkg="" ;;
  esac
  if [[ -n "$pkg" ]] && pkg_install "$pkg" >/dev/null 2>&1; then
    info "$pkg 安装完成"
    return
  fi
  # 兜底: 下载官方 release 到用户字体目录 (任何发行版都能用, 无需 root)
  if [[ -d "$fonts_dir/JetBrainsMono" ]] || fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd"; then
    info "JetBrainsMono Nerd Font 已安装, 跳过"
    return
  fi
  warn "下载 JetBrainsMono Nerd Font 到 $fonts_dir ..."
  mkdir -p "$fonts_dir"
  local url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
  if curl -fsSL "$url" -o /tmp/JetBrainsMono.zip 2>/dev/null && unzip -oq /tmp/JetBrainsMono.zip -d "$fonts_dir/JetBrainsMono" 2>/dev/null; then
    rm -f /tmp/JetBrainsMono.zip
    command -v fc-cache >/dev/null 2>&1 && fc-cache -f "$fonts_dir" >/dev/null 2>&1 || true
    info "JetBrainsMono Nerd Font 安装完成"
  else
    warn "字体安装失败, 请手动下载: $url"
  fi
}

install_cask() { # macOS 专用 (brew cask)
  if [[ "$IS_MACOS" != "1" ]]; then
    warn "install_cask 仅在 macOS 可用 (跳过 $1)"
    return
  fi
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

install_util() { # 系统自带工具 (zsh/curl/git): 命令已存在即跳过, 避免无谓覆盖系统版本
  # macOS 自带 /bin/zsh /usr/bin/curl /usr/bin/git; 多数 Linux 也自带 curl/git
  # 检测: command -v (POSIX 内建, 不 fork 外部进程) 优先; which (通用, 输出路径) 兜底
  # FORCE_BREW_TOOLS=1 可强制安装 brew 版 (仅 macOS)
  local name="$1" found=""
  if command -v "$name" >/dev/null 2>&1; then
    found="$(command -v "$name" 2>/dev/null)"
  elif which "$name" >/dev/null 2>&1; then
    found="$(which "$name" 2>/dev/null)"
  fi
  if [[ -n "$found" ]]; then
    info "$name 已存在 ($found), 跳过"
    return
  fi
  install_formula "$name"
}

install_herdr() { # herdr (官方 install.sh, 二进制落在 ~/.local/bin)
  # 实测: 全新 Linux 的 PATH 不含 ~/.local/bin, 官方安装脚本只会提示而不会写入,
  # 导致本脚本后续 command -v herdr 失败、zshrc 自动启动也永远不触发。
  # 故这里自己把 ~/.local/bin 加到 PATH, 并确保 zshrc 里有 export。
  if ! command -v herdr >/dev/null 2>&1 && [[ -x "$HOME/.local/bin/herdr" ]]; then
    export PATH="$HOME/.local/bin:$PATH"
  fi
  if command -v herdr >/dev/null 2>&1; then
    info "herdr 已安装 ($(herdr --version 2>/dev/null || echo '?'))"
  else
    warn "安装 herdr ..."
    if curl -fsSL https://herdr.dev/install.sh | sh; then
      export PATH="$HOME/.local/bin:$PATH"
      info "herdr 安装完成"
    else
      warn "herdr 安装失败, 请手动运行: curl -fsSL https://herdr.dev/install.sh | sh"
      return
    fi
  fi
  ensure_local_bin_path
}

ensure_local_bin_path() { # 让 ~/.local/bin 在新 shell 里可用 (herdr/uv/bun 都装这里)
  # 原 PATH 里已有则不必写 (macOS 的 brew shellenv 常已包含)
  case ":$ORIG_PATH:" in
    *":$HOME/.local/bin:"*) return 0 ;;
  esac
  local line='export PATH="$HOME/.local/bin:$PATH"'
  [[ -f "$ZSHRC" ]] || touch "$ZSHRC"
  grep -qF "$line" "$ZSHRC" 2>/dev/null && return 0
  printf '\n# ---- ~/.local/bin (herdr/uv/bun 等) ----\n%s\n' "$line" >> "$ZSHRC"
  info "已把 ~/.local/bin 加入 $ZSHRC"
}

install_skills() { # agent skills -> ~/.agents/skills (多数 agent 自动读取; npx skills 会软链到 Claude Code 等)
  # 注意: npx skills add 失败时也返回 0 (实测), 所以用"目录是否新增"判断结果, 不看退出码
  if ! command -v npx >/dev/null 2>&1; then
    warn "未找到 npx (需要 node), 跳过 agent skills 安装; 装好 node 后重跑本脚本即可"
    install_herdr_skill_fallback
    return
  fi
  local entry src skills before after
  local -a skill_args
  for entry in "${SKILL_PACKAGES[@]}"; do
    src="${entry%%|*}"
    skills="${entry#*|}"
    if source_installed "$src" "$skills"; then
      info "skills 已安装, 跳过: $src"
      continue
    fi
    # 用数组传参: skills 为 "*" 时若不引号, 会被 shell 当通配符展开成当前目录文件名
    skill_args=()
    read -r -a skill_args <<< "$skills"
    warn "安装 skills: $src ($skills) ..."
    before="$(count_skills)"
    npx --yes skills@latest add "$src" -g -y -s ${skill_args[@]+"${skill_args[@]}"} >/dev/null 2>&1 || true
    after="$(count_skills)"
    if [[ "$after" -gt "$before" ]]; then
      info "skills 安装完成: $src (+$((after - before)))"
    else
      warn "skills 未新增: $src (可能已全部存在, 或该源不可用)"
    fi
  done
  install_herdr_skill_fallback
}

source_installed() { # 该源的 skill 是否都已装好
  # 显式名字: 逐个查目录, 缺任何一个就重装 (能补齐半途失败的)
  # wildcard "*": 名字未知, 退回查 lock 里是否登记过该源
  local src="$1" skills="$2" skill
  if [[ "$skills" == "*" ]]; then
    [[ -f "$SKILLS_LOCK" ]] || return 1
    grep -qF "\"source\": \"$src\"" "$SKILLS_LOCK" 2>/dev/null
    return
  fi
  for skill in $skills; do
    [[ -d "$SKILLS_DIR/$skill" ]] || return 1
  done
  return 0
}

count_skills() { # 安全计数 (set -e + pipefail 下, 目录不存在时 ls 会失败并中止脚本)
  if [[ -d "$SKILLS_DIR" ]]; then
    ls -1 "$SKILLS_DIR" | wc -l | tr -d ' '
  else
    echo 0
  fi
}

install_herdr_skill_fallback() { # herdr skill 兜底: 无 npx 时用 herdr 自带副本 (herdr --skill)
  [[ -f "$SKILLS_DIR/herdr/SKILL.md" ]] && return 0
  local herdr_bin=""
  if command -v herdr >/dev/null 2>&1; then
    herdr_bin="$(command -v herdr)"
  elif [[ -x "$HOME/.local/bin/herdr" ]]; then
    herdr_bin="$HOME/.local/bin/herdr"
  fi
  [[ -n "$herdr_bin" ]] || return 0
  mkdir -p "$SKILLS_DIR/herdr"
  if "$herdr_bin" --skill > "$SKILLS_DIR/herdr/SKILL.md" 2>/dev/null; then
    info "herdr skill 安装完成 (herdr --skill 回退)"
  else
    warn "herdr skill 安装失败, 请手动运行: npx skills add herdrdev/herdr --skill herdr -g"
  fi
}

# ---------- 1.5 基础工具 (下载/克隆基础: 系统自带即跳过) ----------
install_util curl
install_util git
[[ "$INSTALL_ZSH" == "1" ]] && install_util zsh

# ---------- 1.6 zsh 栈 (oh-my-zsh + 插件, 依赖 curl/git) ----------
# 依据: https://github.com/ohmyzsh/ohmyzsh/wiki/Installing-ZSH
install_zsh_stack() {
  # zsh/curl/git 已由 1.5 基础工具步骤确保

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

# ---------- 1.7 运行时/包管理器 (uv/bun, 依赖 curl) ----------
# 版本比较用上方已定义的 ver_ge (见文件开头)

install_devtools_base() { # uv/bun (运行时/包管理器)
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

  # nvm + node (nvm 是 shell 函数, 需 source 后调用; npm 是很多包安装的前置)
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

install_devtools_apps() { # omp (上层工具, 依赖 bun)
  # oh-my-pi (@oh-my-pi/pi-coding-agent, bin: omp) — 要求 bun >= 1.3.14
  if [[ "$INSTALL_OMP" == "1" ]]; then
    # bun 版本检查: 过低则自动升级 (brew 版用 brew upgrade, 独立安装用 bun upgrade)
    local bun_ver=""
    if command -v bun >/dev/null 2>&1; then
      bun_ver="$(bun --version 2>/dev/null || echo 0)"
    fi
    if [[ -n "$bun_ver" ]] && ! ver_ge "$bun_ver" "1.3.14"; then
      warn "bun $bun_ver 过低, oh-my-pi 需要 bun >= 1.3.14, 正在升级 ..."
      if [[ -x "$HOME/.bun/bin/bun" ]]; then
        bun upgrade >/dev/null 2>&1 || true
      elif command -v brew >/dev/null 2>&1 && brew list --versions bun >/dev/null 2>&1; then
        brew upgrade bun >/dev/null 2>&1 || true
      else
        bun upgrade >/dev/null 2>&1 || true
      fi
      bun_ver="$(bun --version 2>/dev/null || echo 0)"
      if ver_ge "$bun_ver" "1.3.14"; then
        info "bun 已升级到 $bun_ver"
      else
        warn "bun 仍为 $bun_ver, 请手动升级: brew upgrade bun 或 https://bun.sh/docs/installation"
      fi
    fi
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
}

# ========== 执行: 按依赖顺序安装 ==========
# 1.5 基础工具 (curl/git/zsh) 已在上方执行
# 1.7 运行时/包管理器 (uv/bun/nvm — npm 是包安装前置)
if [[ "$INSTALL_DEVTOOLS" == "1" ]]; then
  install_devtools_base
fi

# 1.6 zsh 栈 (oh-my-zsh + 插件 + zshrc)
if [[ "$INSTALL_ZSH" == "1" ]]; then
  install_zsh_stack
fi

# 应用层 (ghostty/herdr/font)
[[ "$INSTALL_GHOSTTY" == "1" ]] && install_ghostty
if [[ "$INSTALL_HERDR" == "1" ]]; then
  install_herdr
  install_herdr_skill_fallback   # herdr 自带 skill, 不依赖 npx; 若已存在则跳过
fi
[[ "$INSTALL_FONT" == "1" ]] && install_font

# agent skills (需 node/npx; 上一段 devtools_base 已装好 nvm+node 并 source, 故此处 npx 可用)
if [[ "$INSTALL_SKILLS" == "1" ]]; then
  install_skills
fi

# 上层工具 (omp 依赖 bun)
if [[ "$INSTALL_DEVTOOLS" == "1" ]]; then
  install_devtools_apps
fi

# ---------- 2. ghostty CLI (macOS: 链接到 brew bin; Linux: 由包管理器提供) ----------
if [[ "$IS_MACOS" == "1" ]]; then
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
# macOS 专属键 (macos-*) 在 Linux 上会校验失败, 故按平台生成
GHOSTTY_EXTRA=""
if [[ "$IS_MACOS" == "1" ]]; then
  GHOSTTY_EXTRA="macos-titlebar-style = hidden
macos-option-as-alt = true"
else
  GHOSTTY_EXTRA="# Linux: 无 macos-* 键 (Ghostty 会拒绝未知键)"
fi
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
$GHOSTTY_EXTRA

scrollback-limit = 10000
mouse-hide-while-typing = true
confirm-close-surface = false
copy-on-select = true
shell-integration = "zsh"
EOF
)"
fi

if [[ "$INSTALL_HERDR" == "1" ]]; then
# 已存在且非空则保留 (herdr 自身也会写入 onboarding = false 等); 空/缺失才写托管配置
if [[ -s "$HERDR_CONFIG" ]]; then
  info "herdr 配置已存在, 保留: $HERDR_CONFIG"
else
write_if_changed "$HERDR_CONFIG" "$(cat <<EOF
# ============ Herdr Config ============
onboarding = false

[theme]
name = "$HERDR_THEME"
EOF
)"
fi
fi

# ---------- 4. zshrc 追加 herdr 自动启动 (幂等) ----------
if [[ "$INSTALL_HERDR" == "1" && "$HERDR_AUTOSTART" == "1" ]]; then
ZSHRC_BLOCK=$(cat <<'EOF'
# ---- herdr autostart (setup-dev-terminal.sh) ----
export HERDR_AUTOSTART=1
if [[ -z "${HERDR_ENV:-}" && -z "${ZELLIJ:-}" && "$HERDR_AUTOSTART" == "1" && "$TERM_PROGRAM" == "ghostty" && $- == *i* ]]; then
  command -v herdr >/dev/null 2>&1 && exec herdr
fi
# ---- end herdr autostart ----
EOF
)
ZSHRC_BLOCK="${ZSHRC_BLOCK//HERDR_AUTOSTART=1/HERDR_AUTOSTART=$HERDR_AUTOSTART}"
if grep -qF "$HERDR_MARKER" "$ZSHRC" 2>/dev/null; then
  info "zshrc 已包含 herdr autostart, 跳过"
else
  [[ -f "$ZSHRC" ]] || touch "$ZSHRC"
  printf '\n%s\n' "$ZSHRC_BLOCK" >> "$ZSHRC"
  info "已追加 herdr autostart 到 $ZSHRC"
fi
fi

# ---------- 5. 验证 ----------
if [[ "$INSTALL_GHOSTTY" == "1" ]]; then
  local_ghostty="$(command -v ghostty 2>/dev/null || echo "")"
  [[ -z "$local_ghostty" && -n "$BREW_BIN" && -x "$BREW_BIN/ghostty" ]] && local_ghostty="$BREW_BIN/ghostty"
  if [[ -n "$local_ghostty" ]] && "$local_ghostty" +validate-config >/dev/null 2>&1; then
    info "Ghostty 配置校验通过"
  elif [[ -n "$local_ghostty" ]]; then
    warn "Ghostty 配置校验失败, 请手动检查 $GHOSTTY_CONFIG"
  else
    warn "未找到 ghostty 命令, 跳过配置校验 ($GHOSTTY_CONFIG)"
  fi
fi

if [[ "$INSTALL_HERDR" == "1" ]]; then
  if command -v herdr >/dev/null 2>&1 && herdr config check >/dev/null 2>&1; then
    info "herdr 配置校验通过"
  elif command -v herdr >/dev/null 2>&1; then
    warn "herdr 配置校验失败, 请手动检查 $HERDR_CONFIG"
  else
    warn "未找到 herdr 命令, 请新开终端后重试, 或手动运行: curl -fsSL https://herdr.dev/install.sh | sh"
  fi
fi

echo
info "全部完成! 平台: $([[ "$IS_MACOS" == "1" ]] && echo macOS || echo "${DISTRO_PRETTY:-Linux}") / $ARCH_RAW"
if [[ "$INSTALL_GHOSTTY" == "1" ]]; then
  if [[ "$IS_MACOS" == "1" ]]; then
    info "打开 Ghostty 即自动进入 herdr (Spotlight 搜 Ghostty)"
  else
    info "打开 Ghostty 即自动进入 herdr (从应用菜单或终端运行 ghostty)"
  fi
else
  info "未安装 Ghostty; 在任意终端运行 herdr 即可"
fi
info "退出 herdr: Ctrl+b 然后 q(分离/回到普通 shell)"
info "关闭自动启动: 改 $ZSHRC 中 HERDR_AUTOSTART=0"
info "zsh 插件需新开终端生效; 若默认 shell 仍是旧 zsh, 可运行: chsh -s \$(which zsh)"
info "nvm 环境在新终端生效 (nvm use $NODE_VERSION); oh-my-pi (omp) 运行 omp 开始使用"
