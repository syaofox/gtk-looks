#!/bin/bash
# 主题安装脚本 - 为 DWM 环境安装 GTK 主题和图标 (Arch Linux 适配版)
# 支持: Mint-Y / Nordic 主题 + lxappearance 配置工具

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
WORK_DIR="/tmp/mint-theme-install-$(date +%s)"
mkdir -p "$WORK_DIR"
trap "rm -rf '$WORK_DIR'" EXIT

# -------------------- 辅助交互函数 --------------------
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

# 多选菜单（逗号分隔编号或 all）
select_items() {
    local title="$1"
    shift
    local items=("$@")
    
    echo ""
    echo "========================================"
    echo "  $title"
    echo "========================================"
    for i in "${!items[@]}"; do
        printf "  %2d) %s\n" $((i+1)) "${items[$i]}"
    done
    echo "----------------------------------------"
    echo "  输入编号选择 (多个用逗号分隔，如 1,3,4)，输入 'all' 全选，直接回车取消"
    echo "----------------------------------------"
    read -p "你的选择: " choice
    
    if [[ -z "$choice" ]]; then
        return 1
    fi
    
    if [[ "$choice" == "all" ]]; then
        for ((i=0; i<${#items[@]}; i++)); do
            echo "$((i+1))"
        done
        return 0
    fi
    
    echo "$choice" | tr ',' '\n' | while read -r num; do
        num=$(echo "$num" | xargs)
        if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#items[@]} ]; then
            echo "$num"
        fi
    done
}

# -------------------- 安装函数 --------------------
install_mint_themes_from_tarball() {
	log_step "安装 Mint-Y 主题 (用户级)..."

	local tarball="$SCRIPT_DIR/themes/mint-themes.tar.gz"
	if [[ ! -f "$tarball" ]]; then
		log_error "主题包不存在: $tarball"
		return 1
	fi

	mkdir -p "$HOME/.local/share/themes"
	tar -xzf "$tarball" -C "$HOME/.local/share/themes/"
	fc-cache -f -v "$HOME/.local/share/themes" 2>/dev/null || true
	log_info "Mint-Y 主题安装完成"
}

install_mint_icons_from_aur() {
	log_step "安装 Mint-Y 图标 (从 AUR)..."

	if ! command -v paru &>/dev/null; then
		log_error "未找到 paru，请先安装 AUR helper"
		return 1
	fi

	paru -S --noconfirm mint-y-icons || {
		log_error "Mint-Y 图标安装失败"
		return 1
	}
	fc-cache -f -v "$HOME/.local/share/icons" 2>/dev/null || true
	log_info "Mint-Y 图标安装完成"
}

install_mint_theme_from_aur() {
	log_step "安装 Mint 主题 (从 AUR)..."

	if ! command -v paru &>/dev/null; then
		log_error "未找到 paru，请先安装 AUR helper"
		return 1
	fi

	paru -S --noconfirm mint-themes || {
		log_error "Mint 主题安装失败"
		return 1
	}
	fc-cache -f -v "$HOME/.local/share/icons" 2>/dev/null || true
	log_info "Mint 主题安装完成"
}

install_catppuccin_aur_packages() {
	log_step "安装 Catppuccin AUR 包..."

	if ! command -v paru &>/dev/null; then
		log_error "未找到 paru，请先安装 AUR helper"
		return 1
	fi

	local packages=(
		"catppuccin-gtk-theme-mocha"
		"catppuccin-gtk-theme-macchiato"
		"catppuccin-gtk-theme-frappe"
		"catppuccin-cursors-latte"
		"catppuccin-fcitx5-git"
		"catppuccin-qt5ct-git"
		"catppuccin-cursors-mocha"
		"catppuccin-cursors-frappe"
	)

	for pkg in "${packages[@]}"; do
		if pacman -Q "$pkg" &>/dev/null; then
			log_warn "$pkg 已安装, 跳过"
		else
			log_info "安装 $pkg..."
			paru -S --noconfirm "$pkg" || log_warn "$pkg 安装失败"
		fi
	done

	fc-cache -f -v "$HOME/.local/share/icons" 2>/dev/null || true
	log_info "Catppuccin AUR 包安装完成"
}

install_catppuccin_themes_from_tarball() {
	log_step "安装 Catppuccin 主题 (用户级)..."

	local tarballs=(
		"$SCRIPT_DIR/themes/Catppuccin-Frappe.tar.gz"
		"$SCRIPT_DIR/themes/Catppuccin-Latte.tar.gz"
		"$SCRIPT_DIR/themes/Catppuccin-Macchiato.tar.gz"
		"$SCRIPT_DIR/themes/Catppuccin-Mocha-Alt.tar.gz"
		"$SCRIPT_DIR/themes/Catppuccin-Mocha-Alt2.tar.gz"
		"$SCRIPT_DIR/themes/Catppuccin-Mocha.tar.gz"
	)

	local installed=0
	for tarball in "${tarballs[@]}"; do
		if [[ -f "$tarball" ]]; then
			tar -xzf "$tarball" -C "$HOME/.local/share/themes/"
			((installed++)) || true
		else
			log_warn "主题包不存在: $tarball"
		fi
	done

	if [[ $installed -gt 0 ]]; then
		fc-cache -f -v "$HOME/.local/share/themes" 2>/dev/null || true
		log_info "Catppuccin 主题安装完成 ($installed 个)"
	else
		log_error "未找到任何 Catppuccin 主题包"
		return 1
	fi
}

install_nordic_icons_from_tarball() {
	log_step "安装 Nordic 图标 (用户级)..."

	local tarball="$SCRIPT_DIR/icons/Nordzy.tar.gz"
	if [[ ! -f "$tarball" ]]; then
		log_error "图标包不存在: $tarball"
		return 1
	fi

	mkdir -p "$HOME/.local/share/icons"
	tar -xzf "$tarball" -C "$HOME/.local/share/icons/"
	fc-cache -f -v "$HOME/.local/share/icons" 2>/dev/null || true
	log_info "Nordic 图标安装完成"
}

install_catppuccin_icons_from_tarball() {
	log_step "安装 Catppuccin 图标 (用户级)..."

	local tarballs=(
		"$SCRIPT_DIR/icons/Catppuccin-Frappe.tar.gz"
		"$SCRIPT_DIR/icons/Catppuccin-Latte.tar.gz"
		"$SCRIPT_DIR/icons/Catppuccin-Macchiato.tar.gz"
		"$SCRIPT_DIR/icons/Catppuccin-Mocha-Alt.tar.gz"
		"$SCRIPT_DIR/icons/Catppuccin-Mocha-Alt2.tar.gz"
		"$SCRIPT_DIR/icons/Catppuccin-Mocha.tar.gz"
	)

	local installed=0
	for tarball in "${tarballs[@]}"; do
		if [[ -f "$tarball" ]]; then
			tar -xzf "$tarball" -C "$HOME/.local/share/icons/"
			((installed++)) || true
		else
			log_warn "图标包不存在: $tarball"
		fi
	done

	if [[ $installed -gt 0 ]]; then
		fc-cache -f -v "$HOME/.local/share/icons" 2>/dev/null || true
		log_info "Catppuccin 图标安装完成 ($installed 个)"
	else
		log_error "未找到任何 Catppuccin 图标包"
		return 1
	fi
}

install_nordic_themes_from_tarball() {
	log_step "安装 Nordic 主题 (用户级)..."

	local tarball="$SCRIPT_DIR/themes/Nordic-v40.tar.xz"
	if [[ ! -f "$tarball" ]]; then
		log_error "主题包不存在: $tarball"
		return 1
	fi

	mkdir -p "$HOME/.local/share/themes"
	tar -xJf "$tarball" -C "$HOME/.local/share/themes/"
	fc-cache -f -v "$HOME/.local/share/themes" 2>/dev/null || true
	log_info "Nordic 主题安装完成"
}

install_lxappearance() {
    log_step "安装 lxappearance..."

    if command -v lxappearance &>/dev/null; then
        log_warn "lxappearance 已安装, 跳过"
        return
    fi

    sudo pacman -S --noconfirm lxappearance || {
        log_error "lxappearance 安装失败"
        return 1
    }
    log_info "lxappearance 安装完成"
}

install_papirus_icons() {
    log_step "安装 Papirus 图标主题..."

    if pacman -Q papirus-icon-theme &>/dev/null; then
        log_warn "Papirus 图标主题已安装, 跳过"
        return
    fi

    sudo pacman -S --noconfirm papirus-icon-theme || {
        log_error "Papirus 图标主题安装失败"
        return 1
    }
    fc-cache -f -v "$HOME/.local/share/icons" 2>/dev/null || true
    log_info "Papirus 图标主题安装完成"
}

install_materia_theme() {
    log_step "安装 Materia GTK 主题..."

    if pacman -Q materia-gtk-theme &>/dev/null; then
        log_warn "Materia GTK 主题已安装, 跳过"
        return
    fi

    sudo pacman -S --noconfirm materia-gtk-theme || {
        log_error "Materia GTK 主题安装失败"
        return 1
    }
    fc-cache -f -v "$HOME/.local/share/themes" 2>/dev/null || true
    log_info "Materia GTK 主题安装完成"
}

# -------------------- GTK 配置相关 --------------------
scan_local_themes() {
    local themes=()
    if [[ -d "$SCRIPT_DIR/themes" ]]; then
        for f in "$SCRIPT_DIR/themes"/*; do
            [[ -f "$f" ]] && themes+=("$(basename "$f")")
        done
    fi
    printf '%s\n' "${themes[@]}" | sort
}

scan_local_icons() {
    local icons=()
    if [[ -d "$SCRIPT_DIR/icons" ]]; then
        for f in "$SCRIPT_DIR/icons"/*; do
            [[ -f "$f" ]] && icons+=("$(basename "$f")")
        done
    fi
    printf '%s\n' "${icons[@]}" | sort
}

install_theme_tarball() {
    local tarball="$1"
    local name="${tarball%.tar.*}"
    local ext="${tarball##*.}"
    local target_dir="$HOME/.local/share/themes"
    
    case "$ext" in
        gz)  [[ "$tarball" == *.tar.gz ]] && ext="tar.gz" ;;
        xz)  ext="tar.xz" ;;
    esac
    
    local src="$SCRIPT_DIR/themes/$tarball"
    if [[ ! -f "$src" ]]; then
        src="$SCRIPT_DIR/icons/$tarball"
        target_dir="$HOME/.local/share/icons"
    fi
    
    if [[ ! -f "$src" ]]; then
        log_error "文件不存在: $tarball"
        return 1
    fi
    
    mkdir -p "$target_dir"
    case "$ext" in
        tar.gz|tgz)
            tar -xzf "$src" -C "$target_dir/" ;;
        tar.xz|txz)
            tar -xJf "$src" -C "$target_dir/" ;;
        zip)
            unzip -q "$src" -d "$target_dir/" ;;
        *)
            log_error "不支持的格式: $ext"
            return 1
    esac
    
    fc-cache -f -v "$target_dir" 2>/dev/null || true
    log_info "已安装: $tarball -> $target_dir"
}

get_available_themes() {
    local themes=()
    if [[ -d /usr/share/themes ]]; then
        for dir in /usr/share/themes/*; do
            [[ -d "$dir" ]] && themes+=("$(basename "$dir")")
        done
    fi
    if [[ -d "$HOME/.local/share/themes" ]]; then
        for dir in "$HOME/.local/share/themes"/*; do
            [[ -d "$dir" ]] && themes+=("$(basename "$dir")")
        done
    fi
    if [[ -d "$HOME/.themes" ]]; then
        for dir in "$HOME/.themes"/*; do
            [[ -d "$dir" ]] && themes+=("$(basename "$dir")")
        done
    fi
    printf '%s\n' "${themes[@]}" | sort -u
}

get_available_icons() {
    local icons=()
    if [[ -d /usr/share/icons ]]; then
        for dir in /usr/share/icons/*; do
            [[ -d "$dir" ]] && icons+=("$(basename "$dir")")
        done
    fi
    if [[ -d "$HOME/.local/share/icons" ]]; then
        for dir in "$HOME/.local/share/icons"/*; do
            [[ -d "$dir" ]] && icons+=("$(basename "$dir")")
        done
    fi
    if [[ -d "$HOME/.icons" ]]; then
        for dir in "$HOME/.icons"/*; do
            [[ -d "$dir" ]] && icons+=("$(basename "$dir")")
        done
    fi
    printf '%s\n' "${icons[@]}" | sort -u
}

configure_gtk_manual() {
    log_step "配置 GTK 设置..."

    mapfile -t themes < <(get_available_themes)
    mapfile -t icons < <(get_available_icons)

    if [[ ${#themes[@]} -eq 0 ]]; then
        log_warn "未找到已安装的主题"
        return 1
    fi

    if [[ ${#icons[@]} -eq 0 ]]; then
        log_warn "未找到已安装的图标"
        return 1
    fi

    echo ""
    echo "选择 GTK 主题:"
    local theme_choice
    theme_choice=$(printf '%s\n' "${themes[@]}" | fzf --height=15 --prompt="选择主题: ")
    if [[ -z "$theme_choice" ]]; then
        log_warn "未选择主题，跳过 GTK 配置"
        return 0
    fi

    echo "选择图标主题:"
    local icon_choice
    icon_choice=$(printf '%s\n' "${icons[@]}" | fzf --height=15 --prompt="选择图标: ")
    if [[ -z "$icon_choice" ]]; then
        log_warn "未选择图标，跳过 GTK 配置"
        return 0
    fi

    log_info "应用主题: $theme_choice"
    log_info "应用图标: $icon_choice"

    mkdir -p "$HOME/.config/gtk-3.0"
    mkdir -p "$HOME/.config/gtk-4.0"

    cat > "$HOME/.config/gtk-3.0/settings.ini" <<EOF
[Settings]
gtk-theme-name = $theme_choice
gtk-icon-theme-name = $icon_choice
gtk-font-name = Sans 10
gtk-cursor-theme-name = Adwaita
gtk-button-images = 0
gtk-menu-images = 0
gtk-toolbar-icon-size = GTK_ICON_SIZE_LARGE
gtk-enable-event-sounds = 1
gtk-enable-input-feedback-sounds = 0
gtk-xft-antialias = 1
gtk-xft-hinting = 1
gtk-xft-hintstyle = hintslight
gtk-xft-rgba = rgb
gtk-decoration-layout = :minimize,maximize,close
EOF
    log_info "GTK3 设置已更新"

    cat > "$HOME/.gtkrc-2.0" <<EOF
gtk-theme-name = "$theme_choice"
gtk-icon-theme-name = "$icon_choice"
gtk-font-name = "Sans 10"
EOF
    log_info "GTK2 设置已更新"

    cat > "$HOME/.config/gtk-4.0/settings.ini" <<EOF
[Settings]
gtk-theme-name=$theme_choice
gtk-icon-theme-name=$icon_choice
gtk-font-name=Sans 10
gtk-cursor-theme-name=Adwaita
EOF
    log_info "GTK4 设置已更新"

    if command -v gtk-update-icon-cache &>/dev/null; then
        for theme_dir in "$HOME/.local/share/themes"/* "$HOME/.themes"/*; do
            [[ -d "$theme_dir" ]] && gtk-update-icon-cache -f -t "$theme_dir" 2>/dev/null || true
        done
        for icon_dir in "$HOME/.local/share/icons"/* "$HOME/.icons"/*; do
            [[ -d "$icon_dir" ]] && gtk-update-icon-cache -f -t "$icon_dir" 2>/dev/null || true
        done
    fi

    log_info "GTK2/3/4 配置完成: 主题=$theme_choice, 图标=$icon_choice"
}

set_nemo_default() {
    log_step "设置 Nemo 为默认文件管理器..."

    if command -v nemo &>/dev/null; then
        xdg-mime default nemo.desktop inode/directory application/x-gnome-saved-search
        log_info "Nemo 已设置为默认文件管理器"
    else
        log_warn "Nemo 未安装, 跳过"
    fi
}

# -------------------- 交互菜单 --------------------
interactive_menu() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}       主题安装 (DWM 环境 - Arch)${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""

    local script_path="${BASH_SOURCE[0]:-$0}"
    if command -v realpath &>/dev/null; then
        SCRIPT_DIR="$(realpath "$(dirname "$script_path")")"
    else
        SCRIPT_DIR="$(cd "$(dirname "$script_path")" && pwd -P)"
    fi

    log_info "脚本目录: $SCRIPT_DIR"

    local options=()
    local theme_files=()
    local icon_files=()

    mapfile -t theme_files < <(scan_local_themes)
    mapfile -t icon_files < <(scan_local_icons)

    for tf in "${theme_files[@]}"; do
        [[ -n "$tf" ]] && options+=("theme:$tf")
    done

    for if in "${icon_files[@]}"; do
        [[ -n "$if" ]] && options+=("icon:$if")
    done

    options+=("catppuccin-aur:Catppuccin AUR")
    options+=("mint-y-icons:Mint-Y 图标 (AUR)")
    options+=("mint-theme:Mint 主题 (AUR)")
    options+=("papirus-icons:Papirus 图标主题")
    options+=("materia-theme:Materia GTK 主题")
    options+=("lxappearance:lxappearance")
    options+=("gtk-config:GTK 配置")
    options+=("nemo-default:Nemo 默认")

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
            theme:*)      install_theme_tarball "${key#theme:}" ;;
            icon:*)       install_theme_tarball "${key#icon:}" ;;
            catppuccin-aur)   install_catppuccin_aur_packages ;;
            mint-y-icons)    install_mint_icons_from_aur ;;
            mint-theme)    install_mint_theme_from_aur ;;
            papirus-icons)   install_papirus_icons ;;
            materia-theme)   install_materia_theme ;;
            lxappearance)  install_lxappearance ;;
            gtk-config)    configure_gtk_manual ;;
            nemo-default) set_nemo_default ;;
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
        echo "  --gui      打开 lxappearance 图形界面"
        exit 0
    fi

    if [[ "${1:-}" == "--gui" ]]; then
        log_info "启动 lxappearance..."
        exec lxappearance
    fi

    if [[ "${1:-}" == "--auto" ]]; then
        local theme_files=()
        local icon_files=()
        
        mapfile -t theme_files < <(scan_local_themes)
        mapfile -t icon_files < <(scan_local_icons)
        
        install_lxappearance
        
        for tf in "${theme_files[@]}"; do
            [[ -n "$tf" ]] && install_theme_tarball "$tf"
        done
        
        for if in "${icon_files[@]}"; do
            [[ -n "$if" ]] && install_theme_tarball "$if"
        done
        
        install_catppuccin_aur_packages
        install_mint_icons_from_aur
        install_mint_theme_from_aur
        configure_gtk_manual
    else
        interactive_menu
    fi
}

main "$@"