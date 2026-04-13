#!/bin/bash
# OpsInstaller - 交互式 Ansible Playbook 执行脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$SCRIPT_DIR/ansible"
PLAYBOOKS_DIR="$ANSIBLE_DIR/playbooks"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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

list_playbooks() {
    log_title "可用的 Playbook 列表"
    echo ""

    local playbooks=()
    local index=1

    while IFS= read -r file; do
        playbooks+=("$file")
        local filename=$(basename "$file")
        local desc=$(get_playbook_description "$file")
        echo -e "  ${BLUE}$index${NC}. $filename"
        echo -e "     描述: $desc"
        echo ""
        index=$((index + 1))
    done < <(find "$PLAYBOOKS_DIR" -maxdepth 1 -name "*.yaml" -type f | sort)

    if [ ${#playbooks[@]} -eq 0 ]; then
        log_error "未找到任何 Playbook 文件"
        exit 1
    fi

    echo "${playbooks[@]}"
}

select_playbook() {
    local playbooks_str=$(list_playbooks)
    local -a playbooks=($playbooks_str)
    local count=${#playbooks[@]}

    if [ $count -eq 0 ]; then
        exit 1
    fi

    while true; do
        read -p "请选择要执行的 Playbook (1-$count): " choice
        if [[ $choice =~ ^[0-9]+$ ]] && [ $choice -ge 1 ] && [ $choice -le $count ]; then
            selected_index=$((choice - 1))
            selected_playbook=${playbooks[$selected_index]}
            break
        else
            log_error "无效的选择，请输入 1 到 $count 之间的数字"
        fi
    done

    echo "$selected_playbook"
}

select_hosts() {
    log_title "主机选择"
    echo ""
    echo -e "  ${BLUE}1${NC}. 所有主机 (all)"
    echo -e "  ${BLUE}2${NC}. 指定主机组"
    echo -e "  ${BLUE}3${NC}. 指定单台主机"
    echo ""

    while true; do
        read -p "请选择目标主机范围 (1-3，默认 1): " host_choice
        host_choice=${host_choice:-1}

        if [ "$host_choice" = "1" ]; then
            limit_option=""
            break
        elif [ "$host_choice" = "2" ]; then
            read -p "请输入主机组名称: " host_group
            if [ -n "$host_group" ]; then
                limit_option="--limit $host_group"
                break
            else
                log_error "主机组名称不能为空"
            fi
        elif [ "$host_choice" = "3" ]; then
            read -p "请输入主机名称: " host_name
            if [ -n "$host_name" ]; then
                limit_option="--limit $host_name"
                break
            else
                log_error "主机名称不能为空"
            fi
        else
            log_error "无效的选择，请输入 1 到 3 之间的数字"
        fi
    done

    echo "$limit_option"
}

confirm_execution() {
    local playbook_file="$1"
    local limit_opt="$2"

    local playbook_name=$(basename "$playbook_file")
    local playbook_desc=$(get_playbook_description "$playbook_file")

    log_title "执行确认"
    echo ""
    echo -e "  Playbook: ${BLUE}$playbook_name${NC}"
    echo -e "  描述:     $playbook_desc"
    if [ -n "$limit_opt" ]; then
        echo -e "  主机范围: ${BLUE}$limit_opt${NC}"
    else
        echo -e "  主机范围: ${BLUE}所有主机${NC}"
    fi
    echo ""

    while true; do
        read -p "确认执行? (y/n，默认 y): " confirm
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
        read -p "请选择执行模式 (1-5，默认 1): " mode_choice
        mode_choice=${mode_choice:-1}

        case "$mode_choice" in
            1)
                extra_options=""
                break
                ;;
            2)
                extra_options="--check"
                break
                ;;
            3)
                extra_options="--check --diff"
                break
                ;;
            4)
                extra_options="-v"
                break
                ;;
            5)
                extra_options="-vvv"
                break
                ;;
            *)
                log_error "无效的选择，请输入 1 到 5 之间的数字"
                ;;
        esac
    done

    echo "$extra_options"
}

execute_playbook() {
    local playbook_file="$1"
    local limit_opt="$2"
    local extra_opt="$3"

    log_title "开始执行"
    echo ""

    cd "$ANSIBLE_DIR"

    local cmd="ansible-playbook $playbook_file $limit_opt $extra_opt"
    log_info "执行命令: $cmd"
    echo ""

    if eval "$cmd"; then
        echo ""
        log_info "Playbook 执行成功！"
    else
        echo ""
        log_error "Playbook 执行失败！"
        return 1
    fi
}

main() {
    log_title "OpsInstaller - 交互式执行脚本"

    check_ansible

    cd "$SCRIPT_DIR"

    selected_playbook=$(select_playbook)

    limit_opt=$(select_hosts)

    extra_opt=$(show_extra_options)

    if confirm_execution "$selected_playbook" "$limit_opt"; then
        execute_playbook "$selected_playbook" "$limit_opt" "$extra_opt"
    fi
}

main "$@"
