#!/bin/bash

# OpenCloudOS 9 服务器自动初始化脚本
# 主执行脚本，整合所有模块

set -e

# 脚本目录
SCRIPT_DIR="$(dirname "$0")/scripts"

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
    if [ -f "$SCRIPT_DIR/../pull.sh" ]; then
        chmod +x "$SCRIPT_DIR/../pull.sh" 2>/dev/null || true
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

# 调用共用的完整初始化函数
full_init "$LOG_FILE"

echo "$(date '+%Y-%m-%d %H:%M:%S') - 初始化脚本执行完成" >> "$LOG_FILE"
echo "=== 初始化完成 ==="
echo "请检查 $LOG_FILE 查看详细执行日志"
echo "root账户登录权限已禁用，请使用新创建的管理员账户进行后续操作"
echo ""
echo "重要提示:"
echo "1. 请使用新创建的管理员账户登录服务器"
echo "2. 首次登录时系统会要求您修改初始密码，初始密码为 ChangeMe123!"
echo "3. 请设置一个强密码，包含大小写字母、数字和特殊字符"
echo "4. 登录命令: ssh $SSH_USER@服务器IP地址 -p $SSH_PORT"
echo ""
echo "初始密码已记录在 $LOG_FILE 中，请查看并妥善保管"