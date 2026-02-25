#!/bin/bash

# OpenCloudOS 9 服务器初始化工具
# 此脚本用于在远程服务器上执行初始化操作

set -e

# 脚本名称
SCRIPT_NAME="$(basename "$0")"
# 目标目录
TARGET_DIR="server_init"
# 仓库地址
REPO_URL="https://github.com/vermantor/server_init.git"

# 检查基本环境
check_environment() {
    echo "Checking basic environment..."
    
    # 确保终端编码为UTF-8
    if [ -z "$LANG" ] || [[ "$LANG" != *UTF-8* ]]; then
        echo "Setting UTF-8 encoding..."
        export LANG=en_US.UTF-8
        export LC_ALL=en_US.UTF-8
        echo "Environment encoding set to UTF-8"
    else
        echo "Environment encoding is already UTF-8"
    fi
    
    # 设置终端类型
    if [ -n "$TERM" ]; then
        export TERM=xterm-256color
        echo "Terminal type set to: $TERM"
    fi
    
    echo "Basic environment check completed"
    echo ""
}



# 强制拉取更新仓库
force_pull_repo() {
    echo "处理代码仓库..."
    
    if [ -d "$TARGET_DIR" ]; then
        echo "仓库目录已存在，正在强制更新..."
        cd "$TARGET_DIR"
        # 强制更新，覆盖本地修改
        git fetch --all
        git reset --hard origin/master
        if [ $? -eq 0 ]; then
            echo "仓库更新成功"
        else
            echo "错误: 仓库更新失败"
            exit 1
        fi
    else
        echo "错误: 仓库目录不存在"
        echo "请确保 $TARGET_DIR 目录存在且是一个git仓库"
        exit 1
    fi
}

# 执行菜单界面
exec_menu() {
    echo "启动初始化菜单界面..."
    if [ -f "run.sh" ]; then
        # 修改权限（无论是否执行菜单都需要修改）
        chmod +x run.sh
        if [ -f "scripts/main.sh" ]; then
            chmod +x scripts/main.sh
        fi
        
        # 添加用户确认环节
        read -p "是否显示初始化菜单？ (y/n): " confirm
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            ./run.sh
        else
            echo "已取消操作，退出脚本"
            exit 0
        fi
    else
        echo "错误: 找不到 run.sh 文件"
        exit 1
    fi
}

# 主函数
main() {
    echo "====================================================="
    echo "      OpenCloudOS 9 服务器初始化工具"
    echo "====================================================="
    echo ""
    
    # 检查基本环境
    check_environment
    
    # 强制拉取更新仓库
    force_pull_repo
    
    # 执行菜单
    exec_menu
}

# 执行主函数
main