#!/bin/bash

# 安全配置模块

# 配置防火墙
configure_firewall() {
    local log_file="$1"
    
    if [ "$ENABLE_FIREWALL" = "yes" ]; then
        # 检查防火墙服务状态
        if ! systemctl is-enabled firewalld &> /dev/null; then
            systemctl enable firewalld
            if [ $? -eq 0 ]; then
                echo "启用防火墙服务成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 启用防火墙服务" >> "$log_file"
            else
                echo "启用防火墙服务失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 启用防火墙服务" >> "$log_file"
                exit 1
            fi
        else
            echo "防火墙服务已启用，跳过"
        fi
        
        if ! systemctl is-active firewalld &> /dev/null; then
            systemctl start firewalld
            if [ $? -eq 0 ]; then
                echo "启动防火墙服务成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 启动防火墙服务" >> "$log_file"
            else
                echo "启动防火墙服务失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 启动防火墙服务" >> "$log_file"
                exit 1
            fi
        else
            echo "防火墙服务已运行，跳过"
        fi
        
        # 配置SSH端口
        echo "配置防火墙SSH端口规则..."
        
        # 关闭默认的22端口
        firewall-cmd --permanent --remove-port=22/tcp
        if [ $? -eq 0 ]; then
            echo "关闭默认22端口成功"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 关闭默认22端口" >> "$log_file"
        else
            echo "关闭默认22端口失败"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 关闭默认22端口" >> "$log_file"
        fi
        
        # 开放配置的SSH端口
        if [ ! -z "$SSH_PORT" ]; then
            firewall-cmd --permanent --add-port="$SSH_PORT"/tcp
            if [ $? -eq 0 ]; then
                echo "开放SSH端口 $SSH_PORT 成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 开放SSH端口 $SSH_PORT" >> "$log_file"
            else
                echo "开放SSH端口 $SSH_PORT 失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 开放SSH端口 $SSH_PORT" >> "$log_file"
            fi
        else
            echo "未配置SSH_PORT，跳过端口开放"
        fi
        
        # 重新加载防火墙配置
        firewall-cmd --reload
        if [ $? -eq 0 ]; then
            echo "防火墙配置重新加载成功"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 重新加载防火墙配置" >> "$log_file"
        else
            echo "防火墙配置重新加载失败"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 重新加载防火墙配置" >> "$log_file"
        fi
    fi
}

# 配置Fail2ban
configure_fail2ban() {
    local log_file="$1"
    
    if [ "$INSTALL_FAIL2BAN" = "yes" ]; then
        # 检查Fail2ban是否已安装
        if ! rpm -q fail2ban &> /dev/null; then
            dnf install -y fail2ban
            if [ $? -eq 0 ]; then
                echo "安装Fail2ban成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 安装Fail2ban" >> "$log_file"
            else
                echo "安装Fail2ban失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 安装Fail2ban" >> "$log_file"
                exit 1
            fi
        else
            echo "Fail2ban已安装，跳过"
        fi
        
        if ! systemctl is-enabled fail2ban &> /dev/null; then
            systemctl enable fail2ban
            if [ $? -eq 0 ]; then
                echo "启用Fail2ban服务成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 启用Fail2ban服务" >> "$log_file"
            else
                echo "启用Fail2ban服务失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 启用Fail2ban服务" >> "$log_file"
                exit 1
            fi
        else
            echo "Fail2ban服务已启用，跳过"
        fi
        
        if ! systemctl is-active fail2ban &> /dev/null; then
            systemctl start fail2ban
            if [ $? -eq 0 ]; then
                echo "启动Fail2ban服务成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 启动Fail2ban服务" >> "$log_file"
            else
                echo "启动Fail2ban服务失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 启动Fail2ban服务" >> "$log_file"
                exit 1
            fi
        else
            echo "Fail2ban服务已运行，跳过"
        fi
    fi
}

# 配置用户权限
configure_user_permissions() {
    local log_file="$1"
    local user_created=false
    local user_verified=false
    
    echo "配置用户权限..."
    
    # 创建新账户
    if [ ! -z "$SSH_USER" ]; then
        echo "创建新账户 $SSH_USER..."
        if ! id -u "$SSH_USER" &> /dev/null; then
            useradd -m "$SSH_USER"
            if [ $? -eq 0 ]; then
                echo "新账户 $SSH_USER 创建成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 创建新账户 $SSH_USER" >> "$log_file"
                
                # 设置新账户密码（临时密码，首次登录需要修改）
                echo "$SSH_USER:ChangeMe123!" | chpasswd
                if [ $? -eq 0 ]; then
                    echo "新账户密码已设置（临时密码：ChangeMe123!）"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 设置新账户密码" >> "$log_file"
                    
                    # 为新账户添加sudo权限
                    echo "$SSH_USER ALL=(ALL) ALL" > "/etc/sudoers.d/$SSH_USER"
                    if [ $? -eq 0 ]; then
                        echo "新账户已添加sudo权限"
                        echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 为新账户添加sudo权限" >> "$log_file"
                        user_created=true
                    else
                        echo "为新账户添加sudo权限失败"
                        echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 为新账户添加sudo权限" >> "$log_file"
                    fi
                else
                    echo "设置新账户密码失败"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 设置新账户密码" >> "$log_file"
                fi
            else
                echo "创建新账户 $SSH_USER 失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 创建新账户 $SSH_USER" >> "$log_file"
            fi
        else
            echo "账户 $SSH_USER 已存在，跳过创建"
            user_created=true
        fi
    else
        echo "未配置SSH_USER，跳过创建新账户"
    fi
    
    # 验证新账户是否可用
    if [ "$user_created" = true ]; then
        echo "验证新账户 $SSH_USER 是否可用..."
        # 测试用户是否可以执行基本命令
        su - "$SSH_USER" -c "echo 'Test command'" &> /dev/null
        if [ $? -eq 0 ]; then
            echo "新账户 $SSH_USER 验证成功"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 验证新账户 $SSH_USER 可用" >> "$log_file"
            user_verified=true
        else
            echo "新账户 $SSH_USER 验证失败"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 验证新账户 $SSH_USER 可用" >> "$log_file"
        fi
    fi
    
    echo "用户权限配置完成"
}

# 禁用root账户登录
# 此功能应在初始化完成后单独执行
disable_root_login() {
    local log_file="$1"
    
    echo "禁用root账户登录权限..."
    
    # 锁定root账户
    passwd -l root &> /dev/null
    if [ $? -eq 0 ]; then
        echo "root账户已禁用"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 禁用root账户" >> "$log_file"
    else
        echo "禁用root账户失败"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 禁用root账户" >> "$log_file"
        exit 1
    fi
    
    # 确保SSH配置中禁用root登录
    current_root_login=$(grep -oP '^PermitRootLogin \K\w+' /etc/ssh/sshd_config 2>/dev/null)
    if [ "$current_root_login" != "no" ]; then
        sed -i 's/^#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
        sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
        
        # 重启SSH服务
        systemctl restart sshd
        if [ $? -eq 0 ]; then
            echo "SSH服务重启成功"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 重启SSH服务" >> "$log_file"
        else
            echo "SSH服务重启失败"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 重启SSH服务" >> "$log_file"
            exit 1
        fi
    else
        echo "SSH配置中已禁用root登录，跳过"
    fi
    
    echo "root账户登录权限禁用完成"
}
