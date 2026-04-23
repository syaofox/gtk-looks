#!/bin/bash
# 常用软件安装脚本 - 交互式多选 (Arch Linux 适配版)
# 纯 Bash 交互，无 whiptail 依赖

# set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "\n${CYAN}==> $1${NC}"; }

[[ "$EUID" -eq 0 ]] && { echo -e "${RED}请勿使用 root 运行此脚本${NC}"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -------------------- 辅助交互函数 (纯 Bash) --------------------
press_enter() {
    echo ""
    read -p "按回车键继续..."
}

yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local ans
    while true; do
        if [[ "$default" == "y" ]]; then
            read -p "$prompt [Y/n]: " ans
        else
            read -p "$prompt [y/N]: " ans
        fi
        ans=${ans:-$default}
        case "$ans" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo "请输入 y 或 n" ;;
        esac
    done
}

# 确保 paru 可用
ensure_paru() {
    if command -v paru &>/dev/null; then
        return 0
    fi
    log_warn "未找到 AUR helper (paru)，将尝试安装..."
    if ! command -v git &>/dev/null; then
        sudo pacman -S --noconfirm git
    fi
    if ! command -v base-devel &>/dev/null; then
        sudo pacman -S --needed --noconfirm base-devel
    fi
    git clone https://aur.archlinux.org/paru.git /tmp/paru
    cd /tmp/paru
    makepkg -si --noconfirm
    cd "$SCRIPT_DIR"
    rm -rf /tmp/paru
    log_info "paru 安装完成"
}

# 确保 flatpak 可用
ensure_flatpak() {
    if ! command -v flatpak &>/dev/null; then
        log_info "安装 flatpak..."
        sudo pacman -S --noconfirm flatpak
    fi
    if ! flatpak remotes | grep -q flathub; then
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    fi
}

# ============================================================
# 主菜单 - 按安装来源分类
# ============================================================

show_main_menu() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}     常用软件安装 (Arch Linux)${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo "  选择安装来源:"
    echo ""
    echo "  1) 官方仓库 (pacman)"
    echo "  2) AUR (paru)"
    echo "  3) Flatpak"
    echo "  4) 安装脚本"
    echo "  5) 全部软件"
    echo ""
    echo "----------------------------------------"
    read -p "你的选择: " main_choice

    case "$main_choice" in
        1) SOURCE="official" ;;
        2) SOURCE="aur" ;;
        3) SOURCE="flatpak" ;;
        4) SOURCE="script" ;;
        5) SOURCE="all" ;;
        *) log_error "无效选择"; exit 1 ;;
    esac
}

show_submenu() {
    local source="$1"
    clear
    echo -e "${CYAN}========================================${NC}"

    case "$source" in
        official)
            echo -e "${CYAN}     官方仓库 (pacman)${NC}"
            OPTIONS_DESC=(
                "Docker + Compose + NVIDIA GPU (开发)"
                "LazyDocker (Docker UI)"
                "uv - Python 包管理器 (开发)"
                "Telegram Desktop (通讯)"
                "Audacity - 音频编辑 (多媒体)"
                "Kdenlive - 视频编辑 (多媒体)"
                "Node.js v24 (nvm/开发)"
            )
            OPTIONS_KEYS=(
                "docker"
                "lazydocker"
                "uv"
                "telegram"
                "audacity"
                "kdenlive"
                "nodejs"
            )
            ;;
        aur)
            echo -e "${CYAN}     AUR (paru)${NC}"
            OPTIONS_DESC=(
                "Brave Browser (浏览器)"
                "Google Chrome (浏览器)"
                "VS Code (IDE)"
                "BackInTime - 备份工具 (系统)"
                "Shelly - Arch 包管理器 (系统)"
            )
            OPTIONS_KEYS=(
                "brave"
                "chrome"
                "vscode"
                "backintime"
                "shelly"
            )
            ;;
        flatpak)
            echo -e "${CYAN}     Flatpak${NC}"
            OPTIONS_DESC=(
                "LocalSend - 局域网传输 (网络)"
                "LosslessCut - 视频处理 (多媒体)"
                "Czkawka - 重复文件清理 (系统)"
                "FSearch - 文件搜索 (系统)"
                "Warehouse - Flatpak 管理 (系统)"
                "GearLever - Flatpak/EXE 启动器 (系统)"
                "FreeFileSync - 文件同步 (系统)"
                "Bottles - Windows 兼容层 (游戏)"
            )
            OPTIONS_KEYS=(
                "localsend"
                "losslesscut"
                "czkawka"
                "fsearch"
                "warehouse"
                "gearlever"
                "freefilesync"
                "bottles"
            )
            ;;
        script)
            echo -e "${CYAN}     安装脚本${NC}"
            OPTIONS_DESC=(
                "OpenCode - AI 代码助手"
            )
            OPTIONS_KEYS=(
                "opencode"
            )
            ;;
        all)
            echo -e "${CYAN}     全部软件${NC}"
            OPTIONS_DESC=(
                "Brave Browser (浏览器/AUR)"
                "Google Chrome (浏览器/AUR)"
                "VS Code (IDE/AUR)"
                "Docker + Compose + NVIDIA GPU (开发/官方)"
                "LazyDocker (Docker UI/官方)"
                "uv - Python 包管理器 (开发/官方)"
                "OpenCode - AI 代码助手 (开发/安装脚本)"
                "Node.js v24 (开发/官方)"
                "LocalSend - 局域网传输 (网络/Flatpak)"
                "Telegram Desktop (通讯/官方)"
                "Audacity - 音频编辑 (多媒体/官方)"
                "Kdenlive - 视频编辑 (多媒体/官方)"
                "LosslessCut - 视频处理 (多媒体/Flatpak)"
                "Czkawka - 重复文件清理 (系统/Flatpak)"
                "FSearch - 文件搜索 (系统/Flatpak)"
                "Warehouse - Flatpak 管理 (系统/Flatpak)"
                "GearLever - Flatpak/EXE 启动器 (系统/Flatpak)"
                "BackInTime - 备份工具 (系统/AUR)"
                "Shelly - Arch 包管理器 (系统/AUR)"
                "FreeFileSync - 文件同步 (系统/Flatpak)"
                "Bottles - Windows 兼容层 (游戏/Flatpak)"
            )
            OPTIONS_KEYS=(
                "brave"
                "chrome"
                "vscode"
                "docker"
                "lazydocker"
                "uv"
                "nodejs"
                "localsend"
                "telegram"
                "audacity"
                "kdenlive"
                "losslesscut"
                "czkawka"
                "fsearch"
                "warehouse"
                "gearlever"
                "backintime"
                "shelly"
                "freefilesync"
                "bottles"
                "opencode"
            )
            ;;
    esac

    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo "可选软件列表:"
    echo ""
    for i in "${!OPTIONS_DESC[@]}"; do
        printf "  %2d) %s\n" $((i+1)) "${OPTIONS_DESC[$i]}"
    done
    echo ""
    echo "----------------------------------------"
    echo "  输入编号选择 (多个用逗号分隔，如 1,3,4)"
    echo "  输入 'all' 全选，直接回车退出"
    echo "----------------------------------------"
    read -p "你的选择: " choice
}

show_main_menu
show_submenu "$SOURCE"

if [[ -z "$choice" ]]; then
    log_warn "未选择任何软件, 退出"
    exit 0
fi

SELECTED=()
if [[ "$choice" == "all" ]]; then
    SELECTED=("${OPTIONS_KEYS[@]}")
else
    IFS=',' read -ra nums <<< "$choice"
    for num in "${nums[@]}"; do
        num=$(echo "$num" | xargs)
        if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#OPTIONS_KEYS[@]} ]; then
            SELECTED+=("${OPTIONS_KEYS[$((num-1))]}")
        fi
    done
fi

if [[ ${#SELECTED[@]} -eq 0 ]]; then
    log_error "没有有效的选择"
    exit 1
fi

echo ""
log_info "已选择: ${SELECTED[*]}"
echo ""
if ! yes_no "确认开始安装？" "y"; then
    log_info "已取消"
    exit 0
fi

# ============================================================
# 安装函数 (Arch 版本) - 保持原有实现不变
# ============================================================

install_brave() {
    log_step "安装 Brave Browser..."
    ensure_paru
    if pacman -Q brave-bin &>/dev/null; then
        log_warn "Brave Browser 已安装, 跳过"
        return
    fi
    paru -S --noconfirm brave-bin
    log_info "Brave Browser 安装完成"
}

install_chrome() {
    log_step "安装 Google Chrome..."
    ensure_paru
    if pacman -Q google-chrome &>/dev/null; then
        log_warn "Google Chrome 已安装, 跳过"
        return
    fi
    paru -S --noconfirm google-chrome
    log_info "Google Chrome 安装完成"
}

install_vscode() {
    log_step "安装 VS Code..."
    ensure_paru
    if pacman -Q code &>/dev/null; then
        log_warn "VS Code 已安装, 跳过"
        return
    fi
    if pacman -Si code &>/dev/null; then
        sudo pacman -S --noconfirm code
    else
        paru -S --noconfirm visual-studio-code-bin
    fi
    log_info "VS Code 安装完成"
}

install_docker() {
    log_step "安装 Docker + Docker Compose + Buildx..."
    if pacman -Q docker &>/dev/null; then
        log_warn "Docker 已安装"
    else
        sudo pacman -S --noconfirm docker docker-compose docker-buildx
        sudo systemctl enable docker.service
        sudo systemctl start docker.service
        sudo usermod -aG docker "$USER"
        log_info "Docker 安装完成 (需重新登录以使用 docker 组)"
    fi

    if [[ ! -f /etc/docker/daemon.json ]] || ! grep -q "registry-mirrors" /etc/docker/daemon.json 2>/dev/null; then
        echo ""
        if yes_no "是否配置 Docker 镜像加速源？" "n"; then
            sudo tee /etc/docker/daemon.json <<'EOF'
{
    "registry-mirrors": [
        "https://docker.1ms.run",
        "https://docker.1panel.live",
        "https://hub.rat.dev",
        "https://dockerproxy.net",
        "https://docker-registry.nmqu.com"
    ]
}
EOF
            sudo systemctl restart docker
            log_info "Docker 镜像加速源已配置"
        fi
    fi

    if command -v nvidia-smi &>/dev/null; then
        if ! pacman -Q nvidia-container-toolkit &>/dev/null; then
            if yes_no "检测到 NVIDIA 驱动，是否安装 Docker GPU 支持？" "y"; then
                sudo pacman -S --noconfirm nvidia-container-toolkit
                sudo nvidia-ctk runtime configure --runtime=docker
                sudo systemctl restart docker
                log_info "NVIDIA Container Toolkit 安装完成"
            fi
        else
            log_info "NVIDIA GPU 支持已配置"
        fi
    fi
}

install_lazydocker() {
    log_step "安装 LazyDocker..."
    if pacman -Q lazydocker &>/dev/null; then
        log_warn "LazyDocker 已安装, 跳过"
        return
    fi
    sudo pacman -S --noconfirm lazydocker
    log_info "LazyDocker 安装完成"
}

install_uv() {
    log_step "安装 uv (Python 包管理器)..."
    if pacman -Q uv &>/dev/null; then
        log_warn "uv 已安装, 跳过"
        return
    fi
    sudo pacman -S --noconfirm uv
    log_info "uv 安装完成"
}

install_opencode() {
    log_step "安装 OpenCode (AI 代码助手)..."

    if ! command -v opencode &>/dev/null; then
        log_info "尝试安装 OpenCode..."
        if curl -fsSL https://opencode.ai/install | bash 2>/dev/null; then
            log_info "OpenCode 安装成功"
        else
            log_warn "官方安装失败，尝试通过 npm 安装..."
            if command -v npm &>/dev/null; then
                npm i -g opencode-ai || log_error "npm 安装失败"
            else
                log_error "未找到 npm，请先安装 Node.js"
                return
            fi
        fi
    else
        log_warn "OpenCode 已安装, 跳过"
    fi

    local config_src="${SCRIPT_DIR}/opencode"
    local config_dest="$HOME/.config/opencode"
    if [[ -d "$config_src" ]]; then
        mkdir -p "$config_dest"
        local total_files=$(find "$config_src" -type f | wc -l)
        while IFS= read -r -d '' src_file; do
            local rel_path="${src_file#$config_src/}"
            local dest_file="$config_dest/$rel_path"
            local dest_dir=$(dirname "$dest_file")
            mkdir -p "$dest_dir"
            cp "$src_file" "$dest_file"
            log_info "部署配置文件: $rel_path"
        done < <(find "$config_src" -type f -print0)
    fi
}

install_nodejs() {
    log_step "安装 Node.js (通过 nvm)..."
    if [[ -d "$HOME/.config/nvm" ]] || [[ -d "$HOME/.nvm" ]]; then
        log_info "nvm 已存在"
    else
        export NVM_DIR="$HOME/.config/nvm"
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
        log_info "nvm 安装完成"
    fi

    if [[ -d "$HOME/.config/nvm" ]]; then
        export NVM_DIR="$HOME/.config/nvm"
    else
        export NVM_DIR="$HOME/.nvm"
    fi
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    if nvm list 24 2>&1 | grep -q "v24"; then
        log_warn "Node.js 24 已安装"
    else
        nvm install 24
        nvm alias default 24
        nvm use 24
    fi
    log_info "Node.js 安装完成 ($(node -v), npm $(npm -v))"
}

install_audacity() {
    log_step "安装 Audacity..."
    if pacman -Q audacity &>/dev/null; then
        log_warn "Audacity 已安装, 跳过"
        return
    fi
    sudo pacman -S --noconfirm audacity
    log_info "Audacity 安装完成"
}

install_bottles() {
    log_step "安装 Bottles (Flatpak)..."
    ensure_flatpak
    if flatpak list | grep -q com.usebottles.Bottles; then
        log_warn "Bottles 已安装, 跳过"
        return
    fi
    flatpak install -y flathub com.usebottles.Bottles
    log_info "Bottles 安装完成"
}

install_freefilesync() {
    log_step "安装 FreeFileSync (Flatpak)..."
    ensure_flatpak
    if flatpak list | grep -q org.freefilesync.FreeFileSync; then
        log_warn "FreeFileSync 已安装, 跳过"
        return
    fi
    flatpak install -y flathub org.freefilesync.FreeFileSync
    log_info "FreeFileSync 安装完成"
}

install_kdenlive() {
    log_step "安装 Kdenlive..."
    if pacman -Q kdenlive &>/dev/null; then
        log_warn "Kdenlive 已安装, 跳过"
        return
    fi
    sudo pacman -S --noconfirm kdenlive
    log_info "Kdenlive 安装完成"
}

install_localsend() {
    log_step "安装 LocalSend (Flatpak)..."
    ensure_flatpak
    if flatpak list | grep -q org.localsend.localsend_app; then
        log_warn "LocalSend 已安装, 跳过"
        return
    fi
    flatpak install -y flathub org.localsend.localsend_app
    log_info "LocalSend 安装完成"
}

install_losslesscut() {
    log_step "安装 LosslessCut (Flatpak)..."
    ensure_flatpak
    if flatpak list | grep -q no.mifi.losslesscut; then
        log_warn "LosslessCut 已安装, 跳过"
        return
    fi
    flatpak install -y flathub no.mifi.losslesscut
    log_info "LosslessCut 安装完成"
}



install_telegram() {
    log_step "安装 Telegram Desktop..."
    if pacman -Q telegram-desktop &>/dev/null; then
        log_warn "Telegram 已安装, 跳过"
        return
    fi
    sudo pacman -S --noconfirm telegram-desktop
    log_info "Telegram 安装完成"
}

install_czkawka() {
    log_step "安装 Czkawka (Flatpak)..."
    ensure_flatpak
    if flatpak list | grep -q com.github.qarmin.czkawka; then
        log_warn "Czkawka 已安装, 跳过"
        return
    fi
    flatpak install -y flathub com.github.qarmin.czkawka
    log_info "Czkawka 安装完成"
}

install_backintime() {
    log_step "安装 BackInTime..."
    ensure_paru
    if pacman -Q backintime &>/dev/null; then
        log_warn "BackInTime 已安装, 跳过"
        return
    fi
    paru -S --noconfirm backintime
    log_info "BackInTime 安装完成"
}

install_shelly() {
    log_step "安装 Shelly..."
    ensure_paru
    if pacman -Q shelly-bin &>/dev/null; then
        log_warn "Shelly 已安装, 跳过"
        return
    fi
    paru -S --noconfirm shelly-bin
    log_info "Shelly 安装完成"
}

install_fsearch() {
    log_step "安装 FSearch (Flatpak)..."
    ensure_flatpak
    if flatpak list | grep -q io.github.cboxdoerfer.FSearch; then
        log_warn "FSearch 已安装, 跳过"
        return
    fi
    flatpak install -y flathub io.github.cboxdoerfer.FSearch
    log_info "FSearch 安装完成"
}

install_warehouse() {
    log_step "安装 Warehouse (Flatpak)..."
    ensure_flatpak
    if flatpak list | grep -q io.github.flattool.Warehouse; then
        log_warn "Warehouse 已安装, 跳过"
        return
    fi
    flatpak install -y flathub io.github.flattool.Warehouse
    log_info "Warehouse 安装完成"
}

install_gearlever() {
    log_step "安装 GearLever (Flatpak/EXE 启动器)..."
    ensure_flatpak
    if flatpak list | grep -q it.mijorus.gearlever; then
        log_warn "GearLever 已安装, 跳过"
        return
    fi
    flatpak install -y flathub it.mijorus.gearlever
    log_info "GearLever 安装完成"
}

# ============================================================
# 执行安装
# ============================================================
for app in "${SELECTED[@]}"; do
    case "$app" in
        brave)        install_brave ;;
        chrome)       install_chrome ;;
        vscode)       install_vscode ;;
        docker)       install_docker ;;
        lazydocker)   install_lazydocker ;;
        uv)           install_uv ;;
        nodejs)       install_nodejs ;;
        opencode)     install_opencode ;;
        audacity)     install_audacity ;;
        bottles)      install_bottles ;;
        freefilesync) install_freefilesync ;;
        kdenlive)     install_kdenlive ;;
        localsend)    install_localsend ;;
        losslesscut)  install_losslesscut ;;
        telegram)     install_telegram ;;
        czkawka)      install_czkawka ;;
        backintime)   install_backintime ;;
        shelly)       install_shelly ;;
        fsearch)      install_fsearch ;;
        warehouse)    install_warehouse ;;
        gearlever)    install_gearlever ;;
        backintime)   install_backintime ;;
        shelly)       install_shelly ;;
        *)            log_warn "未知选项: $app" ;;
    esac
done

log_step "安装完成!"
echo ""
log_info "提示: 如果安装了 Docker, 需要注销重新登录以使 docker 组权限生效"