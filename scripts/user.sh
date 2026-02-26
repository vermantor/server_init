#!/bin/bash

# 用户管理模块

# 禁用指定账户的密码登录
disable_account_password() {
    local account="$1"
    local log_file="$2"
    
    # 尝试锁定账户
    passwd -l "$account" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已禁用账户 $account 的密码登录" >> "$log_file"
    else
        echo "警告: 禁用账户 $account 密码登录失败（权限不足），跳过"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 禁用账户 $account 密码登录（权限不足）" >> "$log_file"
        # 不退出，继续执行后续步骤
    fi
    

}

# 允许指定账户的密码登录
allow_account_password() {
    local account="$1"
    local log_file="$2"
    
    echo "允许账户 $account 的密码登录..."
    
    # 尝试解锁账户
    passwd -u "$account" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "账户 $account 密码登录已允许"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已允许账户 $account 的密码登录" >> "$log_file"
    else
        echo "允许账户 $account 密码登录失败（权限不足），跳过"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 允许账户 $account 密码登录（权限不足）" >> "$log_file"
        # 不退出，继续执行后续步骤
    fi
    
    # 确保SSH配置中PasswordAuthentication为yes
    if [ -w "/etc/ssh/sshd_config" ]; then
        sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null
        sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null
        
        # 重启SSH服务
        systemctl restart sshd 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "SSH服务已重启，PasswordAuthentication设置为yes"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已设置PasswordAuthentication为yes并重启SSH服务" >> "$log_file"
        else
            echo "警告: SSH服务重启失败（权限不足），跳过"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 重启SSH服务（权限不足）" >> "$log_file"
        fi
    else
        echo "警告: 无法修改SSH配置文件（权限不足），跳过"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 无法修改SSH配置文件（权限不足）" >> "$log_file"
    fi

}

# 禁用指定账户的SSH登录
disable_account_ssh() {
    local account="$1"
    local log_file="$2"
    
    # 尝试修改SSH配置
    if [ -w "/etc/ssh/sshd_config" ]; then
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
        
        # 尝试重载SSH服务
        systemctl reload sshd 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已重载SSH服务" >> "$log_file"
        else
            echo "警告: SSH服务重载失败（权限不足），跳过"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 重载SSH服务（权限不足）" >> "$log_file"
        fi
    else
        echo "警告: 无法修改SSH配置文件（权限不足），跳过"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 无法修改SSH配置文件（权限不足）" >> "$log_file"
    fi
    

}

# 允许指定账户的SSH登录
allow_account_ssh() {
    local account="$1"
    local log_file="$2"
    
    echo "允许账户 $account 的SSH登录..."
    
    # 尝试修改SSH配置
    if [ -w "/etc/ssh/sshd_config" ]; then
        # 删除Match块
        sed -i "/^Match User $account/,/^[^ ]/d" /etc/ssh/sshd_config
        
        # 尝试重载SSH服务
        systemctl reload sshd 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "SSH服务重载成功"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已重载SSH服务" >> "$log_file"
        else
            echo "SSH服务重载失败（权限不足），跳过"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 重载SSH服务（权限不足）" >> "$log_file"
        fi
        
        echo "账户 $account 的SSH登录已允许"
    else
        echo "无法修改SSH配置文件（权限不足），跳过"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 无法修改SSH配置文件（权限不足）" >> "$log_file"
    fi
    

}

# 显示账户登录状态
show_account_status() {
    echo "====================================================="
    echo "账户登录权限信息"
    echo "====================================================="
    
    # 检查root账户密码登录状态
    if passwd -S root 2>/dev/null | grep -q "L"; then
        echo "Root密码登录: 已禁用"
    else
        echo "Root密码登录: 已启用"
    fi
    
    # 检查root账户SSH登录状态
    if grep -q "^Match User root" /etc/ssh/sshd_config 2>/dev/null; then
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
        if grep -q "^Match User $SSH_USER" /etc/ssh/sshd_config 2>/dev/null; then
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
            # 尝试创建用户，使用 -p '*' 不配置密码
            useradd -p '*' "$SSH_USER" 2>/dev/null
            if [ $? -eq 0 ]; then
                echo "用户 $SSH_USER 创建成功（未配置密码）"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已创建用户 $SSH_USER（未配置密码）" >> "$log_file"
            else
                echo "警告: 创建用户 $SSH_USER 失败（权限不足），跳过"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 创建用户 $SSH_USER（权限不足）" >> "$log_file"
                # 不退出，继续执行后续步骤
            fi
            
            # 强制用户在首次登录时设置密码
            passwd -e "$SSH_USER" 2>/dev/null
            if [ $? -eq 0 ]; then
                echo "已设置用户 $SSH_USER 首次登录时必须设置密码"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已设置用户 $SSH_USER 首次登录时必须设置密码" >> "$log_file"
            else
                echo "警告: 设置用户 $SSH_USER 首次登录时设置密码失败（权限不足），跳过"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 设置用户 $SSH_USER 首次登录时设置密码（权限不足）" >> "$log_file"
            fi
            
            # 尝试添加到sudo组
            usermod -aG wheel "$SSH_USER" 2>/dev/null
            if [ $? -eq 0 ]; then
                echo "用户 $SSH_USER 已添加到sudo组"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已将用户 $SSH_USER 添加到sudo组" >> "$log_file"
            else
                echo "警告: 将用户 $SSH_USER 添加到sudo组失败（权限不足），跳过"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 将用户 $SSH_USER 添加到sudo组（权限不足）" >> "$log_file"
                # 不退出，继续执行后续步骤
            fi

        else
            echo "账户 $SSH_USER 已存在，跳过创建"
            # 尝试添加到sudo组
            usermod -aG wheel "$SSH_USER" 2>/dev/null
            if [ $? -eq 0 ]; then
                echo "用户 $SSH_USER 已添加到sudo组"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已将用户 $SSH_USER 添加到sudo组" >> "$log_file"
            else
                echo "警告: 将用户 $SSH_USER 添加到sudo组失败（权限不足），跳过"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 将用户 $SSH_USER 添加到sudo组（权限不足）" >> "$log_file"
            fi
        fi
        
        # 设置SSH公钥
        configure_ssh_key "$SSH_USER" "$log_file"

        # 这一步确保账户创建成功并且具有sudo权限
        if id -u "$SSH_USER" &> /dev/null; then
            # 检查用户是否具有sudo权限（检查是否属于wheel组或sudo组）
            if groups "$SSH_USER" 2>/dev/null | grep -q -E 'sudo|wheel'; then
                echo "用户 $SSH_USER 验证成功，具有sudo权限"
                success=0  # 成功
            else
                echo "警告: 用户 $SSH_USER 验证失败，未具有sudo权限"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 用户 $SSH_USER 验证失败，未具有sudo权限" >> "$log_file"
                # 不退出，继续执行后续步骤
            fi
        else
            echo "警告: 用户 $SSH_USER 不存在"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 用户 $SSH_USER 不存在" >> "$log_file"
            # 不退出，继续执行后续步骤
        fi
    else
        echo "警告: SSH_USER未配置，跳过新账户创建"
    fi
    
    echo "用户[$SSH_USER]创建完成."
    return $success
}

# 配置用户SSH公钥
configure_ssh_key() {
    local user="$1"
    local log_file="$2"
    local ssh_dir="/home/$user/.ssh"
    
    # 使用PROJECT_ROOT环境变量构建source目录路径
    local pub_key_file="$PROJECT_ROOT/source/ssh_key.pub"
    
    echo "配置用户 $user 的SSH公钥..."
    
    # 尝试创建.ssh目录
    mkdir -p "$ssh_dir" 2>/dev/null
    chmod 700 "$ssh_dir" 2>/dev/null
    
    # 检查公钥文件是否存在
    if [ -f "$pub_key_file" ]; then
        # 读取公钥内容
        pub_key=$(cat "$pub_key_file" 2>/dev/null)
        
        # 检查公钥是否已经存在于authorized_keys文件中
        if [ -f "$ssh_dir/authorized_keys" ]; then
            if grep -q "$pub_key" "$ssh_dir/authorized_keys" 2>/dev/null; then
                echo "SSH公钥已存在于用户 $user 的authorized_keys中，跳过"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 信息: SSH公钥已存在于用户 $user 的authorized_keys中" >> "$log_file"
                return 0
            fi
        fi
        
        # 尝试将公钥添加到authorized_keys
        echo "$pub_key" >> "$ssh_dir/authorized_keys" 2>/dev/null
        chmod 600 "$ssh_dir/authorized_keys" 2>/dev/null
        chown -R "$user:$user" "$ssh_dir" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo "SSH公钥已添加到用户 $user 的authorized_keys"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已将SSH公钥添加到用户 $user" >> "$log_file"
        else
            echo "警告: 添加SSH公钥失败（权限不足），跳过"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 向用户 $user 添加SSH公钥（权限不足）" >> "$log_file"
        fi
    else
        echo "警告: 未找到 $pub_key_file 文件，跳过公钥配置"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 警告: 未找到 $pub_key_file 文件" >> "$log_file"
    fi
}
