#!/bin/bash
# ==============================================================================
# 脚本名称: centos7_init.sh
# 脚本功能: CentOS 7 生产环境系统初始化脚本
# 适用环境: CentOS 7 (64位)
# ==============================================================================
# ------------------------------------------------------------------------------
# 1. 基础检查
# ------------------------------------------------------------------------------
# 必须以 root 身份运行
if [ "$EUID" -ne 0 ]; then
  echo "请以 root 身份运行此脚本！"
  exit 1
fi

# 检查系统版本
if ! grep -q "CentOS Linux release 7" /etc/redhat-release; then
  echo "警告: 此脚本专为 CentOS 7 设计，您的系统版本可能不兼容。"
  read -p "是否继续运行？(y/n): " confirm
  if [ "$confirm" != "y" ]; then
    exit 1
  fi
fi

echo ">>> 开始进行系统初始化..."

# ------------------------------------------------------------------------------
# 2. 更新系统并安装常用工具
# ------------------------------------------------------------------------------
echo ">>> 更新 YUM 源并安装常用工具..."

# 备份原有的 yum 源
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak

# 使用 阿里云 YUM 源
curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo

yum clean all
yum makecache

# 安装常用工具
yum install -y epel-release
yum install -y vim wget curl net-tools lsof unzip zip git gcc gcc-c++ make cmake \
               bash-completion ntpdate chrony iptables-services bridge-utils \
               psmisc tree telnet rsync nfs-utils

# ------------------------------------------------------------------------------
# 3. 配置时区
# ------------------------------------------------------------------------------
echo ">>> 配置时区..."

# 设置时区为 上海
timedatectl set-timezone Asia/Shanghai

# ------------------------------------------------------------------------------
# 4. 禁用 SELinux 和 防火墙 (根据生产要求，通常在云环境中使用安全组)
# ------------------------------------------------------------------------------
echo ">>> 禁用 SELinux 和 Firewalld..."

# 禁用 SELinux
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

# 禁用 Firewalld (建议根据实际需要开启特定的防火墙策略)
systemctl stop firewalld
systemctl disable firewalld

# ------------------------------------------------------------------------------
# 5. 优化内核参数 (sysctl.conf)
# ------------------------------------------------------------------------------
echo ">>> 优化内核参数..."

cat > /etc/sysctl.conf <<EOF
# 网络连接优化
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.tcp_syncookies = 1
EOF

sysctl -p

# ------------------------------------------------------------------------------
# 6. 优化文件句柄限制 (limits.conf)
# ------------------------------------------------------------------------------
echo ">>> 优化文件句柄限制..."

cat > /etc/security/limits.d/20-nproc.conf <<EOF
*          soft    nproc     65535
root       soft    nproc     unlimited
EOF

cat >> /etc/security/limits.conf <<EOF
* soft nofile 65535
* hard nofile 65535
* soft nproc 65535
* hard nproc 65535
EOF

# ------------------------------------------------------------------------------
# 7. SSH 服务加固
# ------------------------------------------------------------------------------
echo ">>> SSH 服务加固..."

# 备份 ssh 配置文件
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# 优化 SSH 配置
sed -i 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config
sed -i 's/GSSAPIAuthentication yes/GSSAPIAuthentication no/' /etc/ssh/sshd_config

systemctl restart sshd

# ------------------------------------------------------------------------------
# 8. 历史记录优化
# ------------------------------------------------------------------------------
echo ">>> 优化 History 记录..."

cat >> /etc/profile <<EOF
# 设置历史记录格式
export HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S $(whoami) "
export HISTSIZE=10000
EOF

source /etc/profile

# ------------------------------------------------------------------------------
# 9. 完成
# ------------------------------------------------------------------------------
echo ">>> 系统初始化完成！建议重启系统以使所有配置生效。"
echo ">>> 重启命令: reboot"
