#!/bin/bash

# Git 检查模块

# 检查并安装git
check_git() {
    local log_file="$1"
    
    echo "检查git安装情况..."
    
    if ! command -v git &> /dev/null; then
        echo "未安装git，正在安装..."
        dnf install -y git
        if [ $? -eq 0 ]; then
            echo "git安装成功"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 安装git" >> "$log_file"
        else
            echo "git安装失败"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 安装git" >> "$log_file"
            exit 1
        fi
    else
        echo "git已安装"
    fi
}
