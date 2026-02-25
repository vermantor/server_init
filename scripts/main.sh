#!/bin/bash

# OpenCloudOS 9 服务器自动初始化脚本
# 主执行脚本，整合所有模块

set -e

# 脚本目录
SCRIPT_DIR="$(dirname "$0")"

# 检查并设置脚本权限
check_script_permissions() {
    echo "检查脚本权限..."
    # 设置scripts目录下所有sh文件的权限
    for script in "$SCRIPT_DIR"/*.sh; do
        if [ -f "$script" ]; then
            chmod +x "$script" 2>/dev/null || true
        fi
    done
    # 设置项目根目录下pull.sh文件的权限
    if [ -f "$(dirname "$SCRIPT_DIR")/pull.sh" ]; then
        chmod +x "$(dirname "$SCRIPT_DIR")/pull.sh" 2>/dev/null || true
    fi
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





# 加载脚本目录下的所有模块
echo "加载配置模块..."
for script in "$SCRIPT_DIR"/*.sh; do
    if [ -f "$script" ] && [ "$(basename "$script")" != "main.sh" ]; then
        echo "加载模块: $(basename "$script")"
        source "$script"
    fi
done
echo "模块加载完成"

# 检查root权限
check_root

# 定义日志文件
LOG_FILE="init.log"
touch "$LOG_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始执行初始化脚本" >> "$LOG_FILE"

# 设置基本语言环境
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
echo "语言环境已设置为 en_US.UTF-8"

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

# 配置SSH目录
configure_ssh_directory "$LOG_FILE"

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
echo "注意: root账户登录权限未禁用，您可以在菜单中选择 '8. 禁用root账户登录' 来执行此操作"
echo "建议在确认新账户可以正常登录后再禁用root账户"
