#!/bin/bash

# OpenCloudOS 9 服务器自动初始化脚本
# 主执行脚本，整合所有模块

# 移除 set -e，因为我们已经在各个函数中处理了错误情况

# 脚本目录
SCRIPT_DIR="$(dirname "$0")/scripts"

# 检查并设置脚本权限
check_script_permissions() {
    # 设置scripts目录下所有sh文件的权限
    for script in "$SCRIPT_DIR"/*.sh; do
        if [ -f "$script" ]; then
            chmod +x "$script" 2>/dev/null || true
        fi
    done
    # 设置项目根目录下pull.sh文件的权限
    if [ -f "$SCRIPT_DIR/../pull.sh" ]; then
        chmod +x "$SCRIPT_DIR/../pull.sh" 2>/dev/null || true
    fi
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
# 静默加载，只在失败时显示提示
for script in "$SCRIPT_DIR"/*.sh; do
    if [ -f "$script" ] && [ "$(basename "$script")" != "main.sh" ]; then
        source "$script" || echo "警告: 加载模块 $(basename "$script") 失败"
    fi
done

# 检查root权限
check_root

# 定义日志文件
LOG_FILE="init.log"
touch "$LOG_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始执行初始化脚本" >> "$LOG_FILE"

# 移除语言环境设置，使用系统默认语言

# 加载配置文件
load_config

# 调用共用的完整初始化函数
full_init "$LOG_FILE"
user_success=$?

echo "$(date '+%Y-%m-%d %H:%M:%S') - 初始化脚本执行完成" >> "$LOG_FILE"
echo "=== 初始化完成 ==="
echo "请检查 $LOG_FILE 查看详细执行日志"

if [ $user_success -eq 0 ]; then
    echo "root账户登录权限已禁用，请使用新创建的管理员账户进行后续操作"
    echo ""
    echo "重要提示:"
    echo "1. 请使用新创建的管理员账户登录服务器"
    echo "2. 首次登录时系统会要求您设置密码"
    echo "3. 请设置一个强密码，包含大小写字母、数字和特殊字符"
    echo "4. 登录命令: ssh $SSH_USER@服务器IP地址 -p $SSH_PORT"
else
    echo "警告:"
    echo "1. 管理员账户创建失败或未具有sudo权限"
    echo "2. 请检查 $LOG_FILE 查看详细错误信息"
    echo "3. 您可能需要手动创建管理员账户并配置权限"
    echo "4. root账户登录已被禁用，请确保您有其他登录方式"
fi