#!/bin/bash

# SSH 配置模块

# 修改SSH端口
configure_ssh_port() {
    local log_file="$1"
    
    if [ ! -z "$SSH_PORT" ]; then
        # 检查SSH端口是否已设置
        current_port=$(grep -oP '^Port \K[0-9]+' /etc/ssh/sshd_config 2>/dev/null)
        if [ "$current_port" = "$SSH_PORT" ]; then
            echo "SSH端口已设置为 $SSH_PORT，跳过"
        else
            # 备份原有SSH配置
            cp -f /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
            if [ $? -eq 0 ]; then
                echo "备份SSH配置成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 备份SSH配置" >> "$log_file"
            else
                echo "备份SSH配置失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 备份SSH配置" >> "$log_file"
                exit 1
            fi
            
            # 修改SSH端口
            sed -i "s/^#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
            sed -i "s/^Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
            
            # 检查防火墙是否安装
            if command -v firewall-cmd &> /dev/null; then
                # 配置防火墙
                # 添加新端口
                firewall-cmd --permanent --add-port=$SSH_PORT/tcp
                if [ $? -eq 0 ]; then
                    echo "添加防火墙规则成功"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 添加防火墙规则" >> "$log_file"
                else
                    echo "添加防火墙规则失败"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 添加防火墙规则" >> "$log_file"
                fi
                
                # 移除原端口（如果不是使用默认端口）
                if [ "$SSH_PORT" != "22" ]; then
                    firewall-cmd --permanent --remove-port=22/tcp
                    if [ $? -eq 0 ]; then
                        echo "移除原SSH端口防火墙规则成功"
                        echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 移除原SSH端口防火墙规则" >> "$log_file"
                    else
                        echo "移除原SSH端口防火墙规则失败"
                        echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 移除原SSH端口防火墙规则" >> "$log_file"
                    fi
                fi
                
                firewall-cmd --reload
                if [ $? -eq 0 ]; then
                    echo "重新加载防火墙配置成功"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 重新加载防火墙配置" >> "$log_file"
                else
                    echo "重新加载防火墙配置失败"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 重新加载防火墙配置" >> "$log_file"
                fi
            else
                echo "防火墙未安装，跳过防火墙配置"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 警告: 防火墙未安装，跳过防火墙配置" >> "$log_file"
            fi
            
            # 重载SSH服务，使配置生效但不中断现有连接
            systemctl reload sshd
            if [ $? -eq 0 ]; then
                echo "重载SSH服务成功，配置已生效"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 重载SSH服务" >> "$log_file"
            else
                echo "重载SSH服务失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 重载SSH服务" >> "$log_file"
            fi
        fi
    fi
}




