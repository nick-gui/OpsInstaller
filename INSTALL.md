# 安装指南

## 环境要求

- 操作系统：CentOS 7+, Ubuntu 18.04+, Debian 9+
- Python：3.8+
- Ansible：2.9+

## 一、本地安装（在目标机器上运行）

### 1. 克隆项目

```bash
git clone <repository-url>
cd OpsInstaller
```

### 2. 运行前置检查

```bash
sudo scripts/pre-check.sh
```

### 3. 安装 Ansible（如果未安装）

```bash
sudo scripts/bootstrap.sh
```

### 4. 执行完整安装

```bash
cd ansible
ansible-playbook playbooks/full-install.yaml
```

### 5. 运行后检查

```bash
sudo scripts/post-install.sh
```

## 二、远程安装（从控制机管理多台服务器）

### 1. 在控制机上安装 Ansible

```bash
# CentOS/RHEL
sudo yum install -y epel-release
sudo yum install -y ansible

# Ubuntu/Debian
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible
```

### 2. 配置 SSH 免密登录

```bash
# 生成 SSH 密钥（如果没有）
ssh-keygen -t rsa -b 4096

# 复制公钥到目标服务器
ssh-copy-id root@your-server-ip
```

### 3. 配置主机清单

编辑 `ansible/inventory/hosts`：

```ini
[web_servers]
web01 ansible_host=192.168.1.10 ansible_user=root
web02 ansible_host=192.168.1.11 ansible_user=root

[db_servers]
db01 ansible_host=192.168.1.20 ansible_user=root
```

### 4. 测试连接

```bash
cd ansible
ansible all -m ping
```

### 5. 执行安装

```bash
# 初始化所有服务器
ansible-playbook playbooks/init-server.yaml

# 在 web_servers 上安装 Docker
ansible-playbook playbooks/install-docker.yaml -l web_servers

# 完整安装
ansible-playbook playbooks/full-install.yaml
```

## 三、自定义配置

### 修改变量

编辑 `ansible/group_vars/all.yaml` 来自定义配置：

```yaml
# 修改时区
system_timezone: "Asia/Shanghai"

# 自定义目录
base_directories:
  - path: "/data"
    owner: "root"
    group: "root"
    mode: "0755"

# Docker 配置
docker_registry_mirrors:
  - "https://your-mirror.example.com"
```

### 磁盘挂载配置

在主机变量或组变量中配置磁盘挂载：

```yaml
# ansible/host_vars/web01.yaml
disk_mounts:
  - device: "/dev/vdb"
    mount_path: "/data"
    fstype: "ext4"
```

## 四、常用 Playbook 说明

| Playbook | 说明 |
|----------|------|
| `init-server.yaml` | 服务器初始化（通用配置、目录、系统参数） |
| `install-tools.yaml` | 安装基础工具（Git） |
| `install-docker.yaml` | 安装 Docker |
| `install-supervisor.yaml` | 安装 Supervisor |
| `mount-disk.yaml` | 挂载磁盘 |
| `full-install.yaml` | 完整安装（包含以上所有） |

## 五、故障排查

### Ansible 连接失败

```bash
# 检查 SSH 连接
ssh root@your-server-ip

# 检查 Python 是否安装
ansible your-server -m setup
```

### Docker 安装失败

检查网络连接和 Docker 仓库是否可访问：

```bash
curl -I https://download.docker.com
```

### 磁盘挂载失败

确认磁盘设备路径正确：

```bash
lsblk
fdisk -l
```

## 获取帮助

如有问题，请查看 [开发文档](docs/开发文档.md) 或提交 Issue。
