#!/bin/bash
# 安装后处理脚本

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

log_info "开始安装后检查..."

# 检查 Docker
if command -v docker &> /dev/null; then
    log_info "检查 Docker..."
    if systemctl is-active --quiet docker; then
        log_info "Docker 服务运行正常"
        docker --version
    else
        log_warn "Docker 服务未运行"
    fi
else
    log_warn "Docker 未安装"
fi

# 检查 Git
if command -v git &> /dev/null; then
    log_info "检查 Git..."
    git --version
else
    log_warn "Git 未安装"
fi

# 检查 Supervisor
if command -v supervisorctl &> /dev/null; then
    log_info "检查 Supervisor..."
    if systemctl is-active --quiet supervisord || systemctl is-active --quiet supervisor; then
        log_info "Supervisor 服务运行正常"
        supervisord --version 2>/dev/null || echo "Supervisor 已安装"
    else
        log_warn "Supervisor 服务未运行"
    fi
else
    log_warn "Supervisor 未安装"
fi

# 检查目录结构
log_info "检查目录结构..."
for dir in /data /data/logs /data/apps /data/config; do
    if [ -d "$dir" ]; then
        log_info "目录存在: $dir"
    else
        log_warn "目录不存在: $dir"
    fi
done

log_info "安装后检查完成"
