#!/bin/bash

# 用户管理模块

# 禁用root账户
disable_root() {
    local log_file="$1"
    
    echo "禁用root账户..."
    
    # 禁用root登录
    if [ "$(grep -c '^root:' /etc/shadow)" -gt 0 ]; then
        # 锁定root账户
        passwd -l root
        if [ $? -eq 0 ]; then
            echo "root账户已锁定"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 锁定root账户" >> "$log_file"
        else
            echo "锁定root账户失败"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 锁定root账户" >> "$log_file"
            exit 1
        fi
    else
        echo "root账户不存在，跳过"
    fi
}

# 创建新账户
create_user() {
    local log_file="$1"
    
    if [ ! -z "$SSH_USER" ]; then
        echo "创建新账户 $SSH_USER..."
        
        # 检查用户是否已存在
        if ! id -u "$SSH_USER" &> /dev/null; then
            # 创建用户
            useradd "$SSH_USER"
            if [ $? -eq 0 ]; then
                echo "用户 $SSH_USER 创建成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 创建用户 $SSH_USER" >> "$log_file"
            else
                echo "创建用户 $SSH_USER 失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 创建用户 $SSH_USER" >> "$log_file"
                exit 1
            fi
            
            # 设置用户密码（随机生成）
            local password=$(openssl rand -base64 12)
            echo "$SSH_USER:$password" | chpasswd
            if [ $? -eq 0 ]; then
                echo "用户 $SSH_USER 密码设置成功"
                echo "密码: $password" | tee -a "$log_file"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 设置用户 $SSH_USER 密码" >> "$log_file"
            else
                echo "设置用户 $SSH_USER 密码失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 设置用户 $SSH_USER 密码" >> "$log_file"
                exit 1
            fi
            
            # 添加到sudo组
            usermod -aG wheel "$SSH_USER"
            if [ $? -eq 0 ]; then
                echo "用户 $SSH_USER 已添加到sudo组"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 将用户 $SSH_USER 添加到sudo组" >> "$log_file"
            else
                echo "添加用户 $SSH_USER 到sudo组失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 将用户 $SSH_USER 添加到sudo组" >> "$log_file"
                exit 1
