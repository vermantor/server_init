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
            sed -i "s/^Port [0-9]\+/Port $SSH_PORT/" /etc/ssh/sshd_config 2>/dev/null
            
            # 保存sed命令的退出状态
            local sed_status=$?
            
            # 检查修改是否成功
            if grep -q "^Port $SSH_PORT" /etc/ssh/sshd_config 2>/dev/null; then
                echo "SSH端口已成功修改为 $SSH_PORT"
            else
                echo "警告: SSH端口修改可能未成功"
            fi
            
            if [ $sed_status -ne 0 ]; then
                echo "警告: 修改SSH端口失败（权限不足），跳过配置"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 修改SSH端口（权限不足）" >> "$log_file"
                return 0
            fi
            
            # 配置SELinux允许SSH使用新端口
            if command -v semanage &> /dev/null; then
                sudo semanage port -a -t ssh_port_t -p tcp $SSH_PORT 2>/dev/null || true
                echo "SELinux已配置允许SSH使用端口 $SSH_PORT"
            else
                echo "警告: semanage工具未安装，尝试安装..."
                # 尝试安装semanage工具
                if command -v yum &> /dev/null; then
                    # CentOS/RHEL系统
                    sudo yum install -y policycoreutils-python 2>/dev/null
                elif command -v apt &> /dev/null; then
                    # Ubuntu/Debian系统
                    sudo apt update 2>/dev/null && sudo apt install -y policycoreutils-python-utils 2>/dev/null
                fi
                # 再次检查semanage命令是否可用
                if command -v semanage &> /dev/null; then
                    sudo semanage port -a -t ssh_port_t -p tcp $SSH_PORT 2>/dev/null || true
                    echo "SELinux已配置允许SSH使用端口 $SSH_PORT"
                else
                    echo "警告: semanage工具安装失败，跳过SELinux配置"
                fi
                # 添加执行参数
                # 配置/etc/sysconfig/sshd文件，添加OPTIONS="-D"
                if [ -f /etc/sysconfig/sshd ]; then
                    # 检查是否已存在OPTIONS行
                    if grep -q "^OPTIONS=" /etc/sysconfig/sshd; then
                        # 修改现有OPTIONS行
                        sudo sed -i "s/^OPTIONS=.*/OPTIONS=\"-D\"/" /etc/sysconfig/sshd 2>/dev/null
                    else
                        # 添加OPTIONS行
                        echo 'OPTIONS="-D"' | sudo tee -a /etc/sysconfig/sshd 2>/dev/null
                    fi
                else
                    # 创建/etc/sysconfig/sshd文件并添加OPTIONS行
                    echo 'OPTIONS="-D"' | sudo tee /etc/sysconfig/sshd 2>/dev/null
                fi
                if [ $? -eq 0 ]; then
                    echo "已在/etc/sysconfig/sshd中配置OPTIONS=\"-D\""
                    echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 配置SSH执行参数" >> "$log_file"
                else
                    echo "警告: 配置/etc/sysconfig/sshd失败（权限不足），跳过"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 配置SSH执行参数（权限不足）" >> "$log_file"
                fi
                
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

            # 还需要检查是否需要修改fail2ban的配置文件
            if [ "$INSTALL_FAIL2BAN" = "yes" ]; then
                # 检查fail2ban配置文件中是否有需要修改的端口
                if grep -q "^port =" /etc/fail2ban/jail.local; then
                    # 替换为新端口
                    sed -i "s/^port = .*/port = $SSH_PORT/" /etc/fail2ban/jail.local
                    echo "fail2ban配置文件已更新为使用新端口 $SSH_PORT"
                fi
            fi
        fi
    else
        echo "警告: SSH_PORT未配置，跳过SSH端口配置"
    fi
}




