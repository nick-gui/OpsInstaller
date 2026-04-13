# OpsInstaller

运维自动化安装工具

## 项目简介

OpsInstaller 是一个基于 Ansible 的运维自动化安装工具，用于快速初始化 Linux 服务器环境、安装常用软件和配置系统参数。

## 功能特性

- **多系统兼容**：支持 CentOS 7+, Ubuntu 18.04+, Debian 9+
- **幂等性设计**：重复执行不会产生副作用
- **模块化架构**：基于 Ansible Roles，可独立使用和组合
- **开箱即用**：提供默认配置，快速部署

## 支持的组件

- **系统初始化**：基础工具安装、时区配置、Vim 配置
- **目录结构**：自定义目录创建
- **系统优化**：内核参数调优
- **软件安装**：Git、Docker、Supervisor
- **磁盘管理**：磁盘格式化与挂载

## 快速开始

### 前置要求

- Python 3.8+
- Ansible 2.9+

### 安装步骤

1. 克隆项目

```bash
git clone <repository-url>
cd OpsInstaller
```

2. 安装 Ansible（如果未安装）

```bash
sudo scripts/bootstrap.sh
```

3. 配置主机清单

编辑 `ansible/inventory/hosts` 文件，配置目标服务器。

4. 执行安装

```bash
cd ansible
ansible-playbook playbooks/full-install.yaml
```

## 使用文档

详细使用说明请参考：
- [开发文档](docs/开发文档.md)
- [使用指南](docs/使用指南.md)

## 项目结构

```
OpsInstaller/
├── ansible/              # Ansible 核心目录
│   ├── playbooks/        # Playbook 剧本
│   ├── roles/            # Roles 角色
│   ├── inventory/        # 主机清单
│   └── group_vars/       # 组变量
├── scripts/              # 辅助脚本
├── docs/                 # 文档
└── README.md
```

## License

MIT
