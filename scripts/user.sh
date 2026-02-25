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
            echo "Root账户已锁定"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已锁定root账户" >> "$log_file"
        else
            echo "锁定root账户失败"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 锁定root账户" >> "$log_file"
            exit 1
        fi
    else
        echo "Root账户不存在，跳过"
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
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已创建用户 $SSH_USER" >> "$log_file"
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
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已设置用户 $SSH_USER 密码" >> "$log_file"
            else
                echo "设置用户 $SSH_USER 密码失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 设置用户 $SSH_USER 密码" >> "$log_file"
                exit 1
            fi
            
            # 添加到sudo组
            usermod -aG wheel "$SSH_USER"
            if [ $? -eq 0 ]; then
                echo "用户 $SSH_USER 已添加到sudo组"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已将用户 $SSH_USER 添加到sudo组" >> "$log_file"
            else
                echo "将用户 $SSH_USER 添加到sudo组失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 将用户 $SSH_USER 添加到sudo组" >> "$log_file"
                exit 1
            fi
            
            # 设置SSH公钥
            local ssh_dir="/home/$SSH_USER/.ssh"
            local pub_key_file="ssh_key.pub"
            
            # 创建.ssh目录
            mkdir -p "$ssh_dir"
            chmod 700 "$ssh_dir"
            
            # 检查公钥文件是否存在
            if [ -f "$pub_key_file" ]; then
                # 将公钥添加到authorized_keys
                cat "$pub_key_file" >> "$ssh_dir/authorized_keys"
                chmod 600 "$ssh_dir/authorized_keys"
                chown -R "$SSH_USER:$SSH_USER" "$ssh_dir"
                
                if [ $? -eq 0 ]; then
                    echo "SSH公钥已添加到用户 $SSH_USER 的authorized_keys"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已将SSH公钥添加到用户 $SSH_USER" >> "$log_file"
                else
                    echo "添加SSH公钥失败"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 向用户 $SSH_USER 添加SSH公钥" >> "$log_file"
                fi
            else
                echo "警告: 未找到 $pub_key_file 文件，跳过公钥配置"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 警告: 未找到 $pub_key_file 文件" >> "$log_file"
            fi
        else
            echo "账户 $SSH_USER 已存在，跳过创建"
        fi
    else
        echo "SSH_USER未配置，跳过新账户创建"
    fi
    
    echo "用户创建完成"
}
