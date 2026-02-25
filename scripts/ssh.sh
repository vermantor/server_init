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
            
            # 配置防火墙
            firewall-cmd --permanent --add-port=$SSH_PORT/tcp
            if [ $? -eq 0 ]; then
                echo "添加防火墙规则成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 添加防火墙规则" >> "$log_file"
            else
                echo "添加防火墙规则失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 添加防火墙规则" >> "$log_file"
                exit 1
            fi
            
            firewall-cmd --reload
            if [ $? -eq 0 ]; then
                echo "重新加载防火墙配置成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 重新加载防火墙配置" >> "$log_file"
            else
                echo "重新加载防火墙配置失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 重新加载防火墙配置" >> "$log_file"
                exit 1
            fi
            
            # 重启SSH服务
            systemctl restart sshd
            if [ $? -eq 0 ]; then
                echo "重启SSH服务成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 重启SSH服务" >> "$log_file"
            else
                echo "重启SSH服务失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 重启SSH服务" >> "$log_file"
                exit 1
            fi
        fi
    fi
}

# 配置SSH目录
configure_ssh_directory() {
    local log_file="$1"
    
    if [ ! -z "$SSH_USER" ]; then
        USER_HOME=$(eval echo ~$SSH_USER)
        SSH_DIR="$USER_HOME/.ssh"
        
        # 检查.ssh目录是否存在
        if [ ! -d "$SSH_DIR" ]; then
            mkdir -p "$SSH_DIR"
            if [ $? -eq 0 ]; then
                echo "创建.ssh目录成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 创建.ssh目录" >> "$log_file"
            else
                echo "创建.ssh目录失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 创建.ssh目录" >> "$log_file"
                exit 1
            fi
            
            chown "$SSH_USER:$SSH_USER" "$SSH_DIR"
            if [ $? -eq 0 ]; then
                echo "设置.ssh目录权限成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 设置.ssh目录权限" >> "$log_file"
            else
                echo "设置.ssh目录权限失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 设置.ssh目录权限" >> "$log_file"
                exit 1
            fi
            
            chmod 700 "$SSH_DIR"
            if [ $? -eq 0 ]; then
                echo "设置.ssh目录权限成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 设置.ssh目录权限" >> "$log_file"
            else
                echo "设置.ssh目录权限失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 设置.ssh目录权限" >> "$log_file"
                exit 1
            fi
        fi
        
        # 确保authorized_keys文件存在
        if [ ! -f "$SSH_DIR/authorized_keys" ]; then
            touch "$SSH_DIR/authorized_keys"
            if [ $? -eq 0 ]; then
                echo "创建authorized_keys文件成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 创建authorized_keys文件" >> "$log_file"
            else
                echo "创建authorized_keys文件失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 创建authorized_keys文件" >> "$log_file"
                exit 1
            fi
        fi
        
        # 检查并设置文件所有者
        current_owner=$(stat -c "%U:%G" "$SSH_DIR/authorized_keys" 2>/dev/null)
        if [ "$current_owner" != "$SSH_USER:$SSH_USER" ]; then
            chown "$SSH_USER:$SSH_USER" "$SSH_DIR/authorized_keys"
            if [ $? -eq 0 ]; then
                echo "设置authorized_keys所有者成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 设置authorized_keys所有者" >> "$log_file"
            else
                echo "设置authorized_keys所有者失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 设置authorized_keys所有者" >> "$log_file"
                exit 1
            fi
        fi
        
        # 检查并设置文件权限（权限不要过大，保持600）
        current_perm=$(stat -c "%a" "$SSH_DIR/authorized_keys" 2>/dev/null)
        if [ "$current_perm" != "600" ]; then
            chmod 600 "$SSH_DIR/authorized_keys"
            if [ $? -eq 0 ]; then
                echo "设置authorized_keys权限成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 设置authorized_keys权限" >> "$log_file"
            else
                echo "设置authorized_keys权限失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 设置authorized_keys权限" >> "$log_file"
                exit 1
            fi
        fi
    fi
}

# 配置用户安全设置
configure_ssh_security() {
    local log_file="$1"
    
    if [ ! -z "$SSH_USER" ]; then
        sshd_config_changed=false
        
        # 检查并禁用root登录
        current_root_login=$(grep -oP '^PermitRootLogin \K\w+' /etc/ssh/sshd_config 2>/dev/null)
        if [ "$current_root_login" != "no" ]; then
            sed -i 's/^#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
            sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
            sshd_config_changed=true
            echo "禁用root登录"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 禁用root登录" >> "$log_file"
        else
            echo "root登录已禁用，跳过"
        fi
        
        # 检查并配置密码验证
        current_pw_auth=$(grep -oP '^PasswordAuthentication \K\w+' /etc/ssh/sshd_config 2>/dev/null)
        if [ "$current_pw_auth" != "$PASSWORD_AUTHENTICATION" ]; then
            if [ "$PASSWORD_AUTHENTICATION" = "yes" ]; then
                sed -i 's/^#PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
                sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
                echo "启用密码验证"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 启用密码验证" >> "$log_file"
            else
                sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
                sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
                echo "禁用密码验证"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 禁用密码验证" >> "$log_file"
            fi
            sshd_config_changed=true
        else
            echo "密码验证已配置为 $PASSWORD_AUTHENTICATION，跳过"
        fi
        
        # 重启SSH服务（如果配置有更改）
        if [ "$sshd_config_changed" = true ]; then
            systemctl restart sshd
            if [ $? -eq 0 ]; then
                echo "重启SSH服务成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 重启SSH服务" >> "$log_file"
            else
                echo "重启SSH服务失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 重启SSH服务" >> "$log_file"
                exit 1
            fi
        fi
    fi
}
