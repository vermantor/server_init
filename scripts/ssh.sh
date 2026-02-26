#!/bin/bash

# SSH 配置模块

# 修改SSH端口
configure_ssh_port() {
    local log_file="$1"
    
    if [ ! -z "$SSH_PORT" ]; then
        # 检查SSH端口是否已设置
        current_port=$(grep -oP '^Port \K[0-9]+' /etc/ssh/sshd_config 2>/dev/null)
        if [ "$current_port" != "$SSH_PORT" ]; then
            # 尝试备份原有SSH配置
            cp -f /etc/ssh/sshd_config /etc/ssh/sshd_config.bak 2>/dev/null
            if [ $? -eq 0 ]; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 备份SSH配置" >> "$log_file"
            else
                echo "警告: 备份SSH配置失败（权限不足），跳过配置"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 备份SSH配置（权限不足）" >> "$log_file"
                return 0
            fi
            
            # 尝试修改SSH端口
            sed -i "s/^#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config 2>/dev/null
            sed -i "s/^Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config 2>/dev/null
            if [ $? -ne 0 ]; then
                echo "警告: 修改SSH端口失败（权限不足），跳过配置"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 修改SSH端口（权限不足）" >> "$log_file"
                return 0
            fi
            
            # 检查防火墙是否安装
            if command -v firewall-cmd &> /dev/null; then
                # 尝试配置防火墙
                # 添加新端口
                firewall-cmd --permanent --add-port=$SSH_PORT/tcp 2>/dev/null
                if [ $? -eq 0 ]; then
                    echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 添加防火墙规则" >> "$log_file"
                else
                    echo "警告: 添加防火墙规则失败（权限不足），跳过"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 添加防火墙规则（权限不足）" >> "$log_file"
                fi
                
                # 移除原端口（如果不是使用默认端口）
                if [ "$SSH_PORT" != "22" ]; then
                    firewall-cmd --permanent --remove-port=22/tcp 2>/dev/null
                    if [ $? -eq 0 ]; then
                        echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 移除原SSH端口防火墙规则" >> "$log_file"
                    else
                        echo "警告: 移除原SSH端口防火墙规则失败（权限不足），跳过"
                        echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 移除原SSH端口防火墙规则（权限不足）" >> "$log_file"
                    fi
                fi
                
                firewall-cmd --reload 2>/dev/null
                if [ $? -eq 0 ]; then
                    echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 重新加载防火墙配置" >> "$log_file"
                else
                    echo "警告: 重新加载防火墙配置失败（权限不足），跳过"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 重新加载防火墙配置（权限不足）" >> "$log_file"
                fi
            else
                echo "警告: 防火墙未安装，跳过防火墙配置"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 警告: 防火墙未安装，跳过防火墙配置" >> "$log_file"
            fi
            
            # 尝试重载SSH服务
            systemctl reload sshd 2>/dev/null
            if [ $? -eq 0 ]; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 重载SSH服务" >> "$log_file"
            else
                echo "警告: 重载SSH服务失败（权限不足），但不影响现有连接"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 重载SSH服务（权限不足）" >> "$log_file"
            fi
        fi
    else
        echo "警告: SSH_PORT未配置，跳过SSH端口配置"
    fi
}




