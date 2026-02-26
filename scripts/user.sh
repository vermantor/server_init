#!/bin/bash

# 用户管理模块

# 禁用指定账户的密码登录
disable_account_password() {
    local account="$1"
    local log_file="$2"
    
    echo "禁用账户 $account 的密码登录..."
    
    # 锁定账户
    passwd -l "$account"
    if [ $? -eq 0 ]; then
        echo "账户 $account 密码登录已禁用"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已禁用账户 $account 的密码登录" >> "$log_file"
    else
        echo "禁用账户 $account 密码登录失败"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 禁用账户 $account 密码登录" >> "$log_file"
        # 不退出，继续执行后续步骤
    fi
    

}

# 允许指定账户的密码登录
allow_account_password() {
    local account="$1"
    local log_file="$2"
    
    echo "允许账户 $account 的密码登录..."
    
    # 解锁账户
    passwd -u "$account"
    if [ $? -eq 0 ]; then
        echo "账户 $account 密码登录已允许"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已允许账户 $account 的密码登录" >> "$log_file"
    else
        echo "允许账户 $account 密码登录失败"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 允许账户 $account 密码登录" >> "$log_file"
        # 不退出，继续执行后续步骤
    fi
    

}

# 禁用指定账户的SSH登录
disable_account_ssh() {
    local account="$1"
    local log_file="$2"
    
    echo "禁用账户 $account 的SSH登录..."
    
    # 检查是否已有Match块
    if grep -q "^Match User $account" /etc/ssh/sshd_config; then
        # 更新现有Match块
        sed -i "/^Match User $account/,/^[^ ]/s/^\s*AllowTcpForwarding.*/    AllowTcpForwarding no/" /etc/ssh/sshd_config
        sed -i "/^Match User $account/,/^[^ ]/s/^\s*X11Forwarding.*/    X11Forwarding no/" /etc/ssh/sshd_config
        sed -i "/^Match User $account/,/^[^ ]/s/^\s*PermitTTY.*/    PermitTTY no/" /etc/ssh/sshd_config
    else
        # 添加新的Match块
        echo "" >> /etc/ssh/sshd_config
        echo "Match User $account" >> /etc/ssh/sshd_config
        echo "    AllowTcpForwarding no" >> /etc/ssh/sshd_config
        echo "    X11Forwarding no" >> /etc/ssh/sshd_config
        echo "    PermitTTY no" >> /etc/ssh/sshd_config
    fi
    
    # 重载SSH服务
    systemctl reload sshd
    if [ $? -eq 0 ]; then
        echo "SSH服务重载成功"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已重载SSH服务" >> "$log_file"
    else
        echo "SSH服务重载失败"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 重载SSH服务" >> "$log_file"
        # 不退出，继续执行后续步骤
    fi
    
    echo "账户 $account 的SSH登录已禁用"
    

}

# 允许指定账户的SSH登录
allow_account_ssh() {
    local account="$1"
    local log_file="$2"
    
    echo "允许账户 $account 的SSH登录..."
    
    # 删除Match块
    sed -i "/^Match User $account/,/^[^ ]/d" /etc/ssh/sshd_config
    
    # 重载SSH服务
    systemctl reload sshd
    if [ $? -eq 0 ]; then
        echo "SSH服务重载成功"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已重载SSH服务" >> "$log_file"
    else
        echo "SSH服务重载失败"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 重载SSH服务" >> "$log_file"
        # 不退出，继续执行后续步骤
    fi
    
    echo "账户 $account 的SSH登录已允许"
    

}

# 显示账户登录状态
show_account_status() {
    echo "====================================================="
    echo "账户登录状态报告"
    echo "====================================================="
    
    # 检查root账户密码登录状态
    if passwd -S root | grep -q "L"; then
        echo "Root密码登录: 已禁用"
    else
        echo "Root密码登录: 已启用"
    fi
    
    # 检查root账户SSH登录状态
    if grep -q "^Match User root" /etc/ssh/sshd_config; then
        echo "Root SSH登录: 已禁用"
    else
        echo "Root SSH登录: 已启用"
    fi
    
    # 检查配置的管理员账户状态
    if [ ! -z "$SSH_USER" ]; then
        # 检查管理员账户密码登录状态
        if passwd -S "$SSH_USER" 2>/dev/null | grep -q "L"; then
            echo "$SSH_USER 密码登录: 已禁用"
        else
            echo "$SSH_USER 密码登录: 已启用"
        fi
        
        # 检查管理员账户SSH登录状态
        if grep -q "^Match User $SSH_USER" /etc/ssh/sshd_config; then
            echo "$SSH_USER SSH登录: 已禁用"
        else
            echo "$SSH_USER SSH登录: 已启用"
        fi
    fi
    
    echo "====================================================="
}

# 禁用root登录（密码和SSH）
disable_root_login() {
    local log_file="$1"
    
    echo "禁用root登录权限..."
    
    # 禁用root密码登录
    disable_account_password "root" "$log_file"
    
    # 禁用root SSH登录
    disable_account_ssh "root" "$log_file"
    
    echo "Root登录权限已完全禁用"
    

}

# 创建新账户
# 返回值：0表示成功，非0表示失败
create_user() {
    local log_file="$1"
    local success=1  # 默认失败
    
    if [ ! -z "$SSH_USER" ]; then
        echo "创建新账户 $SSH_USER..."
        
        # 检查用户是否已存在
        if ! id -u "$SSH_USER" &> /dev/null; then
            # 创建用户
            useradd "$SSH_USER"
            if [ $? -eq 0 ]; then
                echo "用户 $SSH_USER 创建成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已创建用户 $SSH_USER" >> "$log_file"
            else
                echo "创建用户 $SSH_USER 失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 创建用户 $SSH_USER" >> "$log_file"
                # 不退出，继续执行后续步骤
            fi
            
            # 设置用户密码（临时密码）
            local password="ChangeMe123!"
            echo "$SSH_USER:$password" | chpasswd
            if [ $? -eq 0 ]; then
                echo "用户 $SSH_USER 密码设置成功（临时密码: $password）"
                echo "密码: $password" | tee -a "$log_file"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已设置用户 $SSH_USER 密码" >> "$log_file"
                
                # 强制用户在首次登录时修改密码
                passwd -e "$SSH_USER"
                if [ $? -eq 0 ]; then
                    echo "已设置用户 $SSH_USER 首次登录时必须修改密码"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已设置用户 $SSH_USER 首次登录时必须修改密码" >> "$log_file"
                else
                    echo "设置用户 $SSH_USER 首次登录时修改密码失败"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 设置用户 $SSH_USER 首次登录时修改密码" >> "$log_file"
                fi
            else
                echo "设置用户 $SSH_USER 密码失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 设置用户 $SSH_USER 密码" >> "$log_file"
                # 不退出，继续执行后续步骤
            fi
            
            # 添加到sudo组
            usermod -aG wheel "$SSH_USER"
            if [ $? -eq 0 ]; then
                echo "用户 $SSH_USER 已添加到sudo组"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已将用户 $SSH_USER 添加到sudo组" >> "$log_file"
            else
                echo "将用户 $SSH_USER 添加到sudo组失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 将用户 $SSH_USER 添加到sudo组" >> "$log_file"
                # 不退出，继续执行后续步骤
            fi

            # 设置SSH公钥
            configure_ssh_key "$SSH_USER" "$log_file"
        else
            echo "账户 $SSH_USER 已存在，跳过创建"
        fi

        # 这一步确保账户创建成功并且具有sudo权限
        if id -u "$SSH_USER" &> /dev/null && groups "$SSH_USER" | grep -q 'sudo'; then
            echo "用户 $SSH_USER 验证成功，具有sudo权限"
            success=0  # 成功
        else
            echo "用户 $SSH_USER 验证失败，未具有sudo权限"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 用户 $SSH_USER 验证失败，未具有sudo权限" >> "$log_file"
            # 不退出，继续执行后续步骤
        fi
    else
        echo "SSH_USER未配置，跳过新账户创建"
    fi
    
    echo "用户[$SSH_USER]创建完成"
    return $success
}

# 配置用户SSH公钥
configure_ssh_key() {
    local user="$1"
    local log_file="$2"
    local ssh_dir="/home/$user/.ssh"
    local pub_key_file="ssh_key.pub"
    
    echo "配置用户 $user 的SSH公钥..."
    
    # 创建.ssh目录
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    
    # 检查公钥文件是否存在
    if [ -f "$pub_key_file" ]; then
        # 将公钥添加到authorized_keys
        cat "$pub_key_file" >> "$ssh_dir/authorized_keys"
        chmod 600 "$ssh_dir/authorized_keys"
        chown -R "$user:$user" "$ssh_dir"
        
        if [ $? -eq 0 ]; then
            echo "SSH公钥已添加到用户 $user 的authorized_keys"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已将SSH公钥添加到用户 $user" >> "$log_file"
        else
            echo "添加SSH公钥失败"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 向用户 $user 添加SSH公钥" >> "$log_file"
        fi
    else
        echo "警告: 未找到 $pub_key_file 文件，跳过公钥配置"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 警告: 未找到 $pub_key_file 文件" >> "$log_file"
    fi
}
