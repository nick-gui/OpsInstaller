#!/bin/bash
# 前置环境检查脚本

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

log_info "开始环境检查..."

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
    log_warn "当前不是 root 用户，建议使用 root 或 sudo 权限运行"
fi

# 检查操作系统
if [ -f /etc/os-release ]; then
    . /etc/os-release
    log_info "检测到操作系统: $PRETTY_NAME"
else
    log_error "无法检测操作系统"
    exit 1
fi

# 检查 Python
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    log_info "检测到 Python: $PYTHON_VERSION"
else
    log_error "未检测到 Python3，请先安装 Python3"
    exit 1
fi

# 检查 Ansible
if command -v ansible &> /dev/null; then
    ANSIBLE_VERSION=$(ansible --version | head -n 1)
    log_info "检测到 $ANSIBLE_VERSION"
else
    log_warn "未检测到 Ansible，将尝试安装"
fi

# 检查网络连接
log_info "检查网络连接..."
if curl -s --connect-timeout 5 https://www.baidu.com > /dev/null; then
    log_info "网络连接正常"
else
    log_warn "网络连接可能存在问题，请检查"
fi

log_info "环境检查完成"
