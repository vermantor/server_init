#!/bin/bash

# 主机名配置模块

# 配置主机名
configure_hostname() {
    local log_file="$1"
    
    if [ ! -z "$HOSTNAME" ]; then
        # 检查主机名是否已设置
        current_hostname=$(hostname)
        if [ "$current_hostname" != "$HOSTNAME" ]; then
            # 尝试修改主机名
            hostnamectl set-hostname "$HOSTNAME" 2>/dev/null
            if [ $? -eq 0 ]; then
                echo "主机名已修改为 $HOSTNAME"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 修改主机名为 $HOSTNAME" >> "$log_file"
            else
                echo "警告: 修改主机名失败（权限不足），跳过"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 修改主机名（权限不足）" >> "$log_file"
                return 0
            fi
            
            # 尝试更新/etc/hostname文件
            echo "$HOSTNAME" > /etc/hostname 2>/dev/null
            if [ $? -eq 0 ]; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 更新/etc/hostname文件" >> "$log_file"
            else
                echo "警告: 更新/etc/hostname文件失败（权限不足），跳过"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 更新/etc/hostname文件（权限不足）" >> "$log_file"
                return 0
            fi
        else
            echo "主机名已设置为 $HOSTNAME，跳过"
        fi
    fi
}