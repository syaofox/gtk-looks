#!/bin/bash
# 主题安装脚本 - 为 DWM 环境安装 GTK 主题和图标 (Arch Linux)
set -euo pipefail

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
WORK_DIR="/tmp/theme-install-$(date +%s)"
mkdir -p "$WORK_DIR"
trap "rm -rf '$WORK_DIR'" EXIT

# -------------------- 通用安装函数 --------------------

# 检查 paru 是否可用
check_paru() {
    if ! command -v paru &>/dev/null; then
        log_error "未找到 paru，请先安装 AUR helper"
        return 1
    fi
}

# 安装 AUR 包（支持单个或多个）
install_aur() {
    local type="$1"  # themes 或 icons
    shift
    local packages=("$@")
    
    check_paru || return 1
    
    local cache_dir="$HOME/.local/share/$type"
    mkdir -p "$cache_dir"
    
    for pkg in "${packages[@]}"; do
        if pacman -Q "$pkg" &>/dev/null; then
            log_warn "$pkg 已安装, 跳过"
        else
            log_info "安装 $pkg..."
            paru -S --noconfirm "$pkg" || log_warn "$pkg 安装失败"
        fi
    done
    
    fc-cache -f -v "$cache_dir" 2>/dev/null || true
}

# 安装单个压缩包
install_single_tarball() {
    local file="$1"
    local type="$2"  # themes 或 icons
    
    if [[ ! -f "$file" ]]; then
        log_error "文件不存在: $file"
        return 1
    fi
    
    local target_dir="$HOME/.local/share/$type"
    mkdir -p "$target_dir"
    
    case "$file" in
        *.tar.gz|*.tgz) tar -xzf "$file" -C "$target_dir/" ;;
        *.tar.xz|*.txz) tar -xJf "$file" -C "$target_dir/" ;;
        *.zip)          unzip -q "$file" -d "$target_dir/" ;;
        *) log_error "不支持的格式: $(basename "$file")"; return 1 ;;
    esac
    
    fc-cache -f -v "$target_dir" 2>/dev/null || true
    log_info "已安装: $(basename "$file")"
}

# 从目录自动扫描并安装所有 tarball
install_from_dir() {
    local type="$1"  # themes 或 icons
    local dir="$SCRIPT_DIR/$type"
    
    if [[ ! -d "$dir" ]]; then
        log_warn "$type 目录不存在: $dir"
        return 1
    fi
    
    local installed=0
    shopt -s nullglob
    for file in "$dir"/*.tar.* "$dir"/*.zip "$dir"/*.tgz "$dir"/*.txz; do
        [[ -f "$file" ]] || continue
        install_single_tarball "$file" "$type"
        ((installed++)) || true
    done
    shopt -u nullglob
    
    if [[ $installed -gt 0 ]]; then
        log_info "安装完成 ($installed 个 $type)"
    else
        log_error "未找到任何可安装的压缩包"
        return 1
    fi
}

# 安装 pacman 包（支持单个或多个）
install_pacman() {
    local packages=("$@")
    
    for pkg in "${packages[@]}"; do
        if pacman -Q "$pkg" &>/dev/null; then
            log_warn "$pkg 已安装, 跳过"
        else
            log_info "安装 $pkg..."
            sudo pacman -S --noconfirm "$pkg" || log_warn "$pkg 安装失败"
        fi
    done
}

# -------------------- 扫描函数 --------------------

scan_local_files() {
    local dir="$1"
    local files=()
    if [[ -d "$dir" ]]; then
        for f in "$dir"/*; do
            [[ -f "$f" ]] && files+=("$(basename "$f")")
        done
    fi
    printf '%s\n' "${files[@]}" | sort
}

# -------------------- 安装函数 --------------------

install_mint_icons() {
    log_step "安装 Mint-Y 图标 (从 AUR)..."
    install_aur icons mint-y-icons
}

install_mint_theme_aur() {
    log_step "安装 Mint 主题 (从 AUR)..."
    install_aur themes mint-themes
}

install_catppuccin_aur() {
    log_step "安装 Catppuccin AUR 包..."
    install_aur icons \
        catppuccin-gtk-theme-mocha \
        catppuccin-gtk-theme-macchiato \
        catppuccin-gtk-theme-frappe \
        catppuccin-cursors-latte \
        catppuccin-fcitx5-git \
        catppuccin-qt5ct-git \
        catppuccin-cursors-mocha \
        catppuccin-cursors-frappe
}

install_nordic_theme_aur() {
    log_step "安装 Nordic 主题 (从 AUR)..."
    install_aur themes nordic-theme
}

install_nordzy_icons_aur() {
    log_step "安装 Nordzy 图标 (从 AUR)..."
    install_aur icons nordzy-icon-theme-git
}

install_papirus_nord_aur() {
    log_step "安装 Papirus-Nord 图标 (从 AUR)..."
    install_aur icons papirus-nord
}

install_papirus_icons() {
    log_step "安装 Papirus 图标主题..."
    install_pacman papirus-icon-theme
    fc-cache -f -v "$HOME/.local/share/icons" 2>/dev/null || true
}

install_materia_theme() {
    log_step "安装 Materia GTK 主题..."
    install_pacman materia-gtk-theme
    fc-cache -f -v "$HOME/.local/share/themes" 2>/dev/null || true
}

# -------------------- 交互菜单 --------------------

interactive_menu() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}       主题安装 (DWM 环境 - Arch)${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""

    local script_path="${BASH_SOURCE[0]:-$0}"
    SCRIPT_DIR="$(cd "$(dirname "$script_path")" && pwd -P)"

    log_info "脚本目录: $SCRIPT_DIR"

    local options=()
    local theme_files=()
    local icon_files=()

    mapfile -t theme_files < <(scan_local_files "$SCRIPT_DIR/themes")
    mapfile -t icon_files < <(scan_local_files "$SCRIPT_DIR/icons")

    for tf in "${theme_files[@]}"; do
        [[ -n "$tf" ]] && options+=("theme:$tf")
    done

    for if in "${icon_files[@]}"; do
        [[ -n "$if" ]] && options+=("icon:$if")
    done

    options+=("catppuccin-aur:Catppuccin AUR")
    options+=("mint-y-icons:Mint-Y 图标 (AUR)")
    options+=("mint-theme:Mint 主题 (AUR)")
    options+=("nordic-theme-aur:Nordic 主题 (AUR)")
    options+=("nordzy-icons-aur:Nordzy 图标 (AUR)")
    options+=("papirus-nord-aur:Papirus-Nord 图标 (AUR)")
    options+=("papirus-icons:Papirus 图标主题")
    options+=("materia-theme:Materia GTK 主题")

    if ! command -v fzf &>/dev/null; then
        log_warn "未找到 fzf，尝试安装..."
        sudo pacman -S --noconfirm fzf
    fi

    local IFS=$'\n'
    local selected=$(for opt in "${options[@]}"; do echo "$opt"; done | fzf --height=20 --multi --prompt="选择 (Tab多选): ")

    if [[ -z "$selected" ]]; then
        log_info "未选择，退出"
        return 0
    fi

    local selected_keys=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && selected_keys+=("${line%%:*}")
    done <<< "$selected"

    for key in "${selected_keys[@]}"; do
        case "$key" in
            theme:*)      install_single_tarball "$SCRIPT_DIR/themes/${key#theme:}" "themes" ;;
            icon:*)       install_single_tarball "$SCRIPT_DIR/icons/${key#icon:}" "icons" ;;
            catppuccin-aur)   install_catppuccin_aur ;;
            mint-y-icons)     install_mint_icons ;;
            mint-theme)       install_mint_theme_aur ;;
            nordic-theme-aur) install_nordic_theme_aur ;;
            nordzy-icons-aur) install_nordzy_icons_aur ;;
            papirus-nord-aur) install_papirus_nord_aur ;;
            papirus-icons)    install_papirus_icons ;;
            materia-theme)    install_materia_theme ;;
        esac
    done

    interactive_menu
}

main() {
    if [[ "${1:-}" == "--help" ]]; then
        echo "用法: $0 [选项]"
        echo ""
        echo "选项:"
        echo "  --help     显示此帮助信息"
        echo "  --auto     自动安装 (不显示交互菜单)"
        exit 0
    fi

    if [[ "${1:-}" == "--auto" ]]; then
        install_from_dir themes
        install_from_dir icons
        install_catppuccin_aur
        install_mint_icons
        install_mint_theme_aur
    else
        interactive_menu
    fi
}

main "$@"
