#!/bin/bash
# OpsInstaller - 交互式 Ansible Playbook 执行脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$SCRIPT_DIR/ansible"
PLAYBOOKS_DIR="$ANSIBLE_DIR/playbooks"

# 清理临时文件的函数
cleanup() {
    if [ -n "$TEMP_INVENTORY_FILE" ] && [ -f "$TEMP_INVENTORY_FILE" ]; then
        log_info "清理临时 inventory 文件..."
        rm -f "$TEMP_INVENTORY_FILE"
    fi
}

# 设置 trap，确保脚本退出时清理临时文件
trap cleanup EXIT

# 检测终端是否支持颜色
if [ -t 1 ] && command -v tput > /dev/null && tput colors > /dev/null 2>&1; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    NC=''
fi

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_title() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

check_ansible() {
    if ! command -v ansible-playbook &> /dev/null; then
        log_error "未检测到 Ansible，请先安装 Ansible"
        echo ""
        log_info "您可以运行以下命令安装 Ansible："
        log_info "  sudo $SCRIPT_DIR/scripts/bootstrap.sh"
        exit 1
    fi
}

get_playbook_description() {
    local playbook_file="$1"
    if [ -f "$playbook_file" ]; then
        local desc=$(grep -E "^- name:" "$playbook_file" | head -1 | sed 's/^- name: //')
        if [ -n "$desc" ]; then
            echo "$desc"
        else
            echo "未知功能"
        fi
    else
        echo "文件不存在"
    fi
}

select_playbook() {
    log_title "可用的 Playbook 列表"
    echo ""

    local playbooks=()
    local index=1

    while IFS= read -r file; do
        playbooks+=("$file")
        local filename=$(basename "$file")
        local desc=$(get_playbook_description "$file")
        echo -e "  ${BLUE}$index${NC}. $filename ($desc)"
        echo ""
        index=$((index + 1))
    done < <(find "$PLAYBOOKS_DIR" -maxdepth 1 -name "*.yaml" -type f | sort)

    local count=${#playbooks[@]}

    if [ ${count} -eq 0 ]; then
        log_error "未找到任何 Playbook 文件"
        exit 1
    fi

    echo -e "  ${BLUE}提示${NC}: 支持多选，例如输入 '1,3,5' 或 '1-3,5' 或 'all'"
    echo ""

    while true; do
        read -p "请选择要执行的 Playbook (1-${count}，输入 exit 退出): " choice
        if [ "$choice" = "exit" ]; then
            log_info "已退出程序"
            exit 0
        fi

        SELECTED_PLAYBOOKS=()
        local valid=true

        if [ "$choice" = "all" ]; then
            for ((i=0; i<${count}; i++)); do
                SELECTED_PLAYBOOKS+=("${playbooks[$i]}")
            done
            break
        fi

        IFS=',' read -ra selections <<< "$choice"
        for sel in "${selections[@]}"; do
            sel=$(echo "$sel" | xargs)
            if [[ $sel =~ ^[0-9]+$ ]]; then
                if [ "$sel" -ge 1 ] && [ "$sel" -le "${count}" ]; then
                    selected_index=$((sel - 1))
                    SELECTED_PLAYBOOKS+=("${playbooks[$selected_index]}")
                else
                    valid=false
                    break
                fi
            elif [[ $sel =~ ^([0-9]+)-([0-9]+)$ ]]; then
                start=${BASH_REMATCH[1]}
                end=${BASH_REMATCH[2]}
                if [ "$start" -ge 1 ] && [ "$end" -le "${count}" ] && [ "$start" -le "$end" ]; then
                    for ((i=start; i<=end; i++)); do
                        selected_index=$((i - 1))
                        SELECTED_PLAYBOOKS+=("${playbooks[$selected_index]}")
                    done
                else
                    valid=false
                    break
                fi
            else
                valid=false
                break
            fi
        done

        if [ "$valid" = true ] && [ ${#SELECTED_PLAYBOOKS[@]} -gt 0 ]; then
            break
        else
            log_error "无效的选择，请输入 1 到 ${count} 之间的数字，多个用逗号分隔（如 1,3,5）或范围（如 1-3），或输入 'all' 选择全部"
        fi
    done
}

select_hosts() {
    log_title "主机选择"
    echo ""
    echo -e "  ${BLUE}1${NC}. 请输入服务器 IP"
    echo -e "  ${BLUE}2${NC}. 请输入主机组名称"
    echo -e "  ${BLUE}3${NC}. 请输入主机名称"
    echo -e "  ${BLUE}4${NC}. 所有主机"
    echo ""

    INVENTORY_OPT=""
    EXTRA_VARS_OPT=""
    TEMP_INVENTORY_FILE=""

    while true; do
        local prompt_text="请选择目标主机范围 (1-4，默认 1，输入 exit 退出): "
        read -p "$prompt_text" host_choice
        if [ "$host_choice" = "exit" ]; then
            log_info "已退出程序"
            exit 0
        fi
        if [ -z "$host_choice" ]; then
            host_choice=1
        fi

        if [ "$host_choice" = "1" ]; then
            read -p "请输入服务器 IP (多个 IP 用逗号分隔，输入 exit 退出): " host_ips
            if [ "$host_ips" = "exit" ]; then
                log_info "已退出程序"
                exit 0
            fi
            if [ -n "$host_ips" ]; then
                local timestamp=$(date +%s)
                local group_name="web_${timestamp}"
                TEMP_INVENTORY_FILE="$ANSIBLE_DIR/inventory/temp_${timestamp}.ini"

                # 创建临时 inventory 文件
                echo "[${group_name}]" > "$TEMP_INVENTORY_FILE"
                # 将逗号分隔的 IP 转换为换行
                echo "$host_ips" | tr ',' '\n' | grep -v '^$' >> "$TEMP_INVENTORY_FILE"

                INVENTORY_OPT="-i $TEMP_INVENTORY_FILE"
                EXTRA_VARS_OPT="-e webserver=${group_name}"
                break
            else
                log_error "服务器 IP 不能为空"
            fi
        elif [ "$host_choice" = "2" ]; then
            read -p "请输入主机组名称 (输入 exit 退出): " host_group
            if [ "$host_group" = "exit" ]; then
                log_info "已退出程序"
                exit 0
            fi
            if [ -n "$host_group" ]; then
                EXTRA_VARS_OPT="-e webserver=${host_group}"
                break
            else
                log_error "主机组名称不能为空"
            fi
        elif [ "$host_choice" = "3" ]; then
            read -p "请输入主机名称 (输入 exit 退出): " host_name
            if [ "$host_name" = "exit" ]; then
                log_info "已退出程序"
                exit 0
            fi
            if [ -n "$host_name" ]; then
                EXTRA_VARS_OPT="-e webserver=${host_name}"
                break
            else
                log_error "主机名称不能为空"
            fi
        elif [ "$host_choice" = "4" ]; then
            EXTRA_VARS_OPT="-e webserver=all"
            break
        else
            log_error "无效的选择，请输入 1 到 4 之间的数字"
        fi
    done
}

confirm_execution() {
    local extra_vars_opt="$1"
    local inventory_opt="$2"
    shift 2
    local playbook_files=("$@")

    log_title "执行确认"
    echo ""
    echo -e "  Playbook(s):"
    for pb in "${playbook_files[@]}"; do
        local pb_name=$(basename "$pb")
        local pb_desc=$(get_playbook_description "$pb")
        echo -e "    ${BLUE}- $pb_name${NC} ($pb_desc)"
    done
    if [ -n "$inventory_opt" ]; then
        local inventory_file=${inventory_opt#-i }
        local display_ips=""
        if [ -f "$inventory_file" ]; then
            display_ips=$(awk 'NF && $1 !~ /^\[/ && $1 !~ /^#/{print $1}' "$inventory_file" | paste -sd "," -)
        fi
        if [ -n "$display_ips" ]; then
            echo -e "  主机范围: ${BLUE}临时 IP ($display_ips)${NC}"
        else
            echo -e "  主机范围: ${BLUE}临时 inventory ($inventory_file)${NC}"
        fi
    elif [ -n "$extra_vars_opt" ]; then
        local display_host=${extra_vars_opt#-e webserver=}
        echo -e "  主机范围: ${BLUE}$display_host${NC}"
    else
        echo -e "  主机范围: ${BLUE}所有主机${NC}"
    fi
    echo ""

    while true; do
        read -p "确认执行? (y/n，默认 y，输入 exit 退出): " confirm
        if [ "$confirm" = "exit" ]; then
            log_info "已退出程序"
            exit 0
        fi
        confirm=${confirm:-y}

        case "$confirm" in
            [Yy]*)
                return 0
                ;;
            [Nn]*)
                log_info "已取消执行"
                return 1
                ;;
            *)
                log_error "无效的输入，请输入 y 或 n"
                ;;
        esac
    done
}

show_extra_options() {
    echo ""
    log_title "额外选项"
    echo ""
    echo -e "  ${BLUE}1${NC}. 正常执行"
    echo -e "  ${BLUE}2${NC}. Dry-run (测试模式，不实际执行)"
    echo -e "  ${BLUE}3${NC}. Dry-run + 显示差异"
    echo -e "  ${BLUE}4${NC}. 显示详细输出 (-v)"
    echo -e "  ${BLUE}5${NC}. 显示更详细输出 (-vvv)"
    echo ""

    while true; do
        read -p "请选择执行模式 (1-5，默认 1，输入 exit 退出): " mode_choice
        if [ "$mode_choice" = "exit" ]; then
            log_info "已退出程序"
            exit 0
        fi
        mode_choice=${mode_choice:-1}

        case "$mode_choice" in
            1)
                EXTRA_OPT=""
                break
                ;;
            2)
                EXTRA_OPT="--check"
                break
                ;;
            3)
                EXTRA_OPT="--check --diff"
                break
                ;;
            4)
                EXTRA_OPT="-v"
                break
                ;;
            5)
                EXTRA_OPT="-vvv"
                break
            ;;
            *)
                log_error "无效的选择，请输入 1 到 5 之间的数字"
                ;;
        esac
    done
}

execute_playbook() {
    local extra_vars_opt="$1"
    local extra_opt="$2"
    local inventory_opt="$3"
    shift 3
    local playbook_files=("$@")

    log_title "开始执行"
    echo ""

    cd "$ANSIBLE_DIR"

    local all_success=true
    for pb in "${playbook_files[@]}"; do
        local pb_name=$(basename "$pb")
        log_info "正在执行: $pb_name"
        echo ""

        local cmd="ansible-playbook $pb $inventory_opt $extra_vars_opt $extra_opt"
        log_info "执行命令: $cmd"
        echo ""

        if eval "$cmd"; then
            echo ""
            log_info "$pb_name 执行成功！"
            echo ""
        else
            echo ""
            log_error "$pb_name 执行失败！"
            echo ""
            all_success=false
        fi
    done

    if [ "$all_success" = true ]; then
        log_info "所有 Playbook 执行完成！"
        return 0
    else
        log_warn "部分 Playbook 执行失败，请检查上方输出"
        return 1
    fi
}

load_env() {
    if [ -f "$SCRIPT_DIR/.env" ]; then
        log_info "发现 .env 文件，正在加载环境变量..."
        set -a
        source "$SCRIPT_DIR/.env"
        set +a
    fi
}

main() {
    log_title "OpsInstaller - 交互式执行脚本"

    check_ansible

    cd "$SCRIPT_DIR"
    load_env

    select_playbook
    select_hosts
    show_extra_options

    execute_playbook "$EXTRA_VARS_OPT" "$EXTRA_OPT" "$INVENTORY_OPT" "${SELECTED_PLAYBOOKS[@]}"
}

main "$@"
