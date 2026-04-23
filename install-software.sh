#!/bin/bash
# 常用软件安装脚本 - 配置文件驱动
# 配置文件: packages.yaml

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
CONFIG_FILE="$SCRIPT_DIR/packages.yaml"

SOURCE=""
TITLE=""

declare -a OFFICIAL_ARR AUR_ARR FLATPAK_ARR SCRIPT_ARR
declare -A OFFICIAL_CMD AUR_CMD FLATPAK_CMD SCRIPT_CMD
declare -A OFFICIAL_DESC AUR_DESC FLATPAK_DESC SCRIPT_DESC
declare -A OFFICIAL_INSTALL AUR_INSTALL FLATPAK_INSTALL SCRIPT_INSTALL
declare -A OFFICIAL_CHECK AUR_CHECK FLATPAK_CHECK SCRIPT_CHECK

ensure_yq() {
    if command -v yq &>/dev/null; then
        return 0
    fi
    log_warn "未找到 yq，将尝试安装..."
    if command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm yq
    elif command -v apt &>/dev/null; then
        sudo apt install -y yq
    else
        log_error "无法安装 yq，请手动安装"
        exit 1
    fi
}

ensure_fzf() {
    if command -v fzf &>/dev/null; then
        return 0
    fi
    log_warn "未找到 fzf，将尝试安装..."
    if command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm fzf
    elif command -v apt &>/dev/null; then
        sudo apt install -y fzf
    fi
}

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

ensure_flatpak() {
    if ! command -v flatpak &>/dev/null; then
        log_info "安装 flatpak..."
        sudo pacman -S --noconfirm flatpak
    fi
    if ! flatpak remotes | grep -q flathub; then
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    fi
}

fzf_multiselect() {
    local title="$1"
    shift
    local items=("$@")
    printf "%s\n" "${items[@]}" | fzf \
        --multi --height=20 \
        --prompt="选择软件 (Tab/空格单选): " \
        --header="$title" \
        --bind "ctrl-a:select-all" \
        --bind "ctrl-d:deselect-all" \
        --bind "ctrl-r:toggle-all" \
        --bind "enter:accept"
}

load_packages() {
    ensure_yq
    
    for type in official aur flatpak script; do
        local count
        count=$(yq ".$type | length" "$CONFIG_FILE")
        
        for i in $(seq 0 $((count - 1))); do
            local name cmd desc install check
            name=$(yq -r ".$type[$i].name" "$CONFIG_FILE")
            cmd=$(yq -r ".$type[$i].command" "$CONFIG_FILE")
            desc=$(yq -r ".$type[$i].desc" "$CONFIG_FILE")
            install=$(yq -r ".$type[$i].install" "$CONFIG_FILE")
            check=$(yq -r ".$type[$i].check" "$CONFIG_FILE")
            
            [[ -z "$name" ]] && continue
            
            case "$type" in
                official)
                    OFFICIAL_ARR+=("$name")
                    OFFICIAL_CMD["$name"]="$cmd"
                    OFFICIAL_DESC["$name"]="$desc"
                    OFFICIAL_INSTALL["$name"]="$install"
                    OFFICIAL_CHECK["$name"]="$check"
                    ;;
                aur)
                    AUR_ARR+=("$name")
                    AUR_CMD["$name"]="$cmd"
                    AUR_DESC["$name"]="$desc"
                    AUR_INSTALL["$name"]="$install"
                    AUR_CHECK["$name"]="$check"
                    ;;
                flatpak)
                    FLATPAK_ARR+=("$name")
                    FLATPAK_CMD["$name"]="$cmd"
                    FLATPAK_DESC["$name"]="$desc"
                    FLATPAK_INSTALL["$name"]="$install"
                    FLATPAK_CHECK["$name"]="$check"
                    ;;
                script)
                    SCRIPT_ARR+=("$name")
                    SCRIPT_CMD["$name"]="$cmd"
                    SCRIPT_DESC["$name"]="$desc"
                    SCRIPT_INSTALL["$name"]="$install"
                    SCRIPT_CHECK["$name"]="$check"
                    ;;
            esac
        done
    done
}

get_options() {
    local source="$1"
    local is_all="${2:-false}"
    
    if [[ "$is_all" != "true" ]]; then
        OPTIONS_KEYS=()
        OPTIONS_DESC=()
    fi
    
    case "$source" in
        official)
            for name in "${OFFICIAL_ARR[@]}"; do
                local desc="${OFFICIAL_DESC[$name]}"
                local check="${OFFICIAL_CHECK[$name]}"
                if eval "$check" 2>/dev/null; then
                    OPTIONS_KEYS+=("$name")
                    OPTIONS_DESC+=("[✓] $desc")
                else
                    OPTIONS_KEYS+=("$name")
                    OPTIONS_DESC+=("[ ] $desc")
                fi
            done
            ;;
        aur)
            for name in "${AUR_ARR[@]}"; do
                local desc="${AUR_DESC[$name]}"
                local check="${AUR_CHECK[$name]}"
                if eval "$check" 2>/dev/null; then
                    OPTIONS_KEYS+=("$name")
                    OPTIONS_DESC+=("[✓] $desc")
                else
                    OPTIONS_KEYS+=("$name")
                    OPTIONS_DESC+=("[ ] $desc")
                fi
            done
            ;;
        flatpak)
            for name in "${FLATPAK_ARR[@]}"; do
                local desc="${FLATPAK_DESC[$name]}"
                local check="${FLATPAK_CHECK[$name]}"
                if eval "$check" 2>/dev/null; then
                    OPTIONS_KEYS+=("$name")
                    OPTIONS_DESC+=("[✓] $desc")
                else
                    OPTIONS_KEYS+=("$name")
                    OPTIONS_DESC+=("[ ] $desc")
                fi
            done
            ;;
        script)
            for name in "${SCRIPT_ARR[@]}"; do
                local desc="${SCRIPT_DESC[$name]}"
                local check="${SCRIPT_CHECK[$name]}"
                if eval "$check" 2>/dev/null; then
                    OPTIONS_KEYS+=("$name")
                    OPTIONS_DESC+=("[✓] $desc")
                else
                    OPTIONS_KEYS+=("$name")
                    OPTIONS_DESC+=("[ ] $desc")
                fi
            done
            ;;
        all)
            get_options "official" "true"
            get_options "aur" "true"
            get_options "flatpak" "true"
            get_options "script" "true"
            ;;
    esac
}

get_install_cmd() {
    local name="$1"
    local source="$2"
    case "$source" in
        official|[Oo]fficial*) echo "${OFFICIAL_INSTALL[$name]}" ;;
        aur|[Aa]ur*) echo "${AUR_INSTALL[$name]}" ;;
        flatpak|[Ff]latpak*) echo "${FLATPAK_INSTALL[$name]}" ;;
        script|[Ss]cript*) echo "${SCRIPT_INSTALL[$name]}" ;;
    esac
}

get_source_by_name() {
    local name="$1"
    [[ -n "${OFFICIAL_INSTALL[$name]:-}" ]] && echo "official" && return
    [[ -n "${AUR_INSTALL[$name]:-}" ]] && echo "aur" && return
    [[ -n "${FLATPAK_INSTALL[$name]:-}" ]] && echo "flatpak" && return
    [[ -n "${SCRIPT_INSTALL[$name]:-}" ]] && echo "script" && return
}

show_cat_menu() {
    clear
    ensure_fzf
    local options=(
        "官方仓库 (pacman)"
        "AUR (paru)"
        "Flatpak"
        "安装脚本"
        "全部软件"
    )
    local choice
    choice=$(printf "%s\n" "${options[@]}" | fzf --height=12 --prompt="选择安装来源: ") || return 1
    [[ -z "$choice" ]] && return 1
    
    case "$choice" in
        "官方仓库"*) SOURCE="official"; TITLE="官方仓库 (pacman)" ;;
        "AUR"*) SOURCE="aur"; TITLE="AUR (paru)" ;;
        "Flatpak"*) SOURCE="flatpak"; TITLE="Flatpak" ;;
        "安装脚本"*) SOURCE="script"; TITLE="安装脚本" ;;
        "全部软件"*) SOURCE="all"; TITLE="全部软件" ;;
        *) return 1 ;;
    esac
}

run_menu() {
    show_cat_menu || return
    
    OPTIONS_KEYS=()
    OPTIONS_DESC=()
    get_options "$SOURCE"
    
    [[ ${#OPTIONS_KEYS[@]} -eq 0 ]] && { log_warn "该分类暂无软件"; return; }
    
    mapfile -t SELECTED < <(fzf_multiselect "$TITLE" "${OPTIONS_DESC[@]}") || return
    
    [[ ${#SELECTED[@]} -eq 0 ]] && { log_warn "未选择任何软件"; return; }
    
    declare -a FINAL_SELECTED APP_SOURCES
    declare -A DESC_TO_KEY
    for i in "${!OPTIONS_KEYS[@]}"; do
        DESC_TO_KEY["${OPTIONS_DESC[$i]}"]="${OPTIONS_KEYS[$i]}"
    done
    
    for item in "${SELECTED[@]}"; do
        key="${DESC_TO_KEY[$item]}"
        FINAL_SELECTED+=("$key")
        if [[ "$SOURCE" == "all" ]]; then
            APP_SOURCES+=("$(get_source_by_name "$key")")
        else
            APP_SOURCES+=("$SOURCE")
        fi
    done

    log_info "安装: ${FINAL_SELECTED[*]}"
    
    for i in "${!FINAL_SELECTED[@]}"; do
        app="${FINAL_SELECTED[$i]}"
        src="${APP_SOURCES[$i]}"
        
        case "$src" in
            aur) ensure_paru ;;
            flatpak) ensure_flatpak ;;
        esac
        
        log_step "安装 $app..."
        cmd=$(get_install_cmd "$app" "$src")
        eval "$cmd"
        log_info "$app 安装成功"
    done
    
    echo ""
    echo -e "${GREEN}✓ 安装完成${NC}"
    sleep 1
}

main() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "配置文件不存在: $CONFIG_FILE"
        exit 1
    fi
    
    echo -e "${YELLOW}加载软件列表并检测安装状态...${NC}"
    load_packages
    
    while true; do
        run_menu || break
    done
    
    echo ""
    echo -e "${CYAN}已退出，再见！${NC}"
}

main "$@"