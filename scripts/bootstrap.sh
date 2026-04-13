#!/bin/bash
# 环境引导脚本 - 安装 Ansible

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

if [ "$EUID" -ne 0 ]; then
    log_error "请使用 root 或 sudo 权限运行此脚本"
    exit 1
fi

log_info "开始安装 Ansible..."

# 检测操作系统
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    log_error "无法检测操作系统"
    exit 1
fi

install_ansible_centos() {
    log_info "在 CentOS/RHEL 上安装 Ansible..."
    yum install -y epel-release
    yum install -y ansible
}

install_ansible_debian() {
    log_info "在 Debian/Ubuntu 上安装 Ansible..."
    apt update
    apt install -y software-properties-common
    add-apt-repository --yes --update ppa:ansible/ansible
    apt install -y ansible
}

case $OS in
    centos|rhel|rocky|almalinux)
        install_ansible_centos
        ;;
    debian|ubuntu)
        install_ansible_debian
        ;;
    *)
        log_error "不支持的操作系统: $OS"
        exit 1
        ;;
esac

if command -v ansible &> /dev/null; then
    ANSIBLE_VERSION=$(ansible --version | head -n 1)
    log_info "安装成功: $ANSIBLE_VERSION"
else
    log_error "Ansible 安装失败"
    exit 1
fi

log_info "Ansible 安装完成"
