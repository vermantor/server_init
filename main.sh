#!/bin/bash

# OpenCloudOS 9 服务器自动初始化脚本
# 主执行脚本，整合所有模块

set -e

# 脚本目录
SCRIPT_DIR="$(dirname "$0")/scripts"

# 检查并设置脚本权限
check_script_permissions() {
    echo "检查脚本权限..."
    for script in "$SCRIPT_DIR"/*.sh; do
        if [ -f "$script" ]; then
            chmod +x "$script" 2>/dev/null || true
        fi
    done
    echo "脚本权限检查完成"
}

# 检查并设置脚本权限
check_script_permissions

# 加载通用函数模块
if [ -f "$SCRIPT_DIR/common.sh" ]; then
    source "$SCRIPT_DIR/common.sh"
else
    echo "错误: 找不到通用函数模块 $SCRIPT_DIR/common.sh"
    exit 1
fi

# 加载语言配置模块
if [ -f "$SCRIPT_DIR/language_config.sh" ]; then
    source "$SCRIPT_DIR/language_config.sh"
else
    echo "错误: 找不到语言配置模块 $SCRIPT_DIR/language_config.sh"
    exit 1
fi

# 加载Git检查模块
if [ -f "$SCRIPT_DIR/git_check.sh" ]; then
    source "$SCRIPT_DIR/git_check.sh"
else
    echo "错误: 找不到Git检查模块 $SCRIPT_DIR/git_check.sh"
    exit 1
fi

# 加载网络配置模块
if [ -f "$SCRIPT_DIR/network.sh" ]; then
    source "$SCRIPT_DIR/network.sh"
else
    echo "错误: 找不到网络配置模块 $SCRIPT_DIR/network.sh"
    exit 1
fi

# 加载SSH配置模块
if [ -f "$SCRIPT_DIR/ssh.sh" ]; then
    source "$SCRIPT_DIR/ssh.sh"
else
    echo "错误: 找不到SSH配置模块 $SCRIPT_DIR/ssh.sh"
    exit 1
fi

# 加载安全配置模块
if [ -f "$SCRIPT_DIR/security.sh" ]; then
    source "$SCRIPT_DIR/security.sh"
else
    echo "错误: 找不到安全配置模块 $SCRIPT_DIR/security.sh"
    exit 1
fi

# 检查root权限
check_root

# 定义日志文件
LOG_FILE="init.log"
touch "$LOG_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始执行初始化脚本" >> "$LOG_FILE"

# 配置语言支持
configure_language "$LOG_FILE"
check_git "$LOG_FILE"

# 加载配置文件
load_config

# 自动检测网络接口
detect_network_interface

# 配置主机名
configure_hostname "$LOG_FILE"

# 配置网络
configure_network "$LOG_FILE"

# 配置SSH端口
configure_ssh_port "$LOG_FILE"

# 生成SSH密钥对
generate_ssh_keys "$LOG_FILE"

# 配置SSH安全设置
configure_ssh_security "$LOG_FILE"

# 配置防火墙
configure_firewall "$LOG_FILE"

# 配置Fail2ban
configure_fail2ban "$LOG_FILE"

# 配置用户权限
configure_user_permissions "$LOG_FILE"

echo "$(date '+%Y-%m-%d %H:%M:%S') - 初始化脚本执行完成" >> "$LOG_FILE"
echo "=== 初始化完成 ==="
echo "请检查 $LOG_FILE 查看详细执行日志"
