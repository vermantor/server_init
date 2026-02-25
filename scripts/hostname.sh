#!/bin/bash

# 主机名配置模块

# 配置主机名
configure_hostname() {
    local log_file="$1"
    
    if [ ! -z "$HOSTNAME" ]; then
        # 检查主机名是否已设置
        current_hostname=$(hostname)
        if [ "$current_hostname" != "$HOSTNAME" ]; then
            hostnamectl set-hostname "$HOSTNAME"
            if [ $? -eq 0 ]; then
                echo "修改主机名成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 修改主机名为 $HOSTNAME" >> "$log_file"
            else
                echo "修改主机名失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 修改主机名" >> "$log_file"
                exit 1
            fi
            
            echo "$HOSTNAME" > /etc/hostname
            if [ $? -eq 0 ]; then
                echo "更新/etc/hostname文件成功"
                echo "当前主机名已经更新为 $HOSTNAME"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 更新/etc/hostname文件" >> "$log_file"
            else
                echo "更新/etc/hostname文件失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 更新/etc/hostname文件" >> "$log_file"
                exit 1
            fi
        else
            echo "主机名已设置为 $HOSTNAME，跳过"
        fi
    fi
}