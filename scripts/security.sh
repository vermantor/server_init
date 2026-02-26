#!/bin/bash

# 安全配置模块

# 配置防火墙
configure_firewall() {
    local log_file="$1"
    
    if [ "$ENABLE_FIREWALL" = "yes" ]; then
        # 检查防火墙服务状态
        if ! systemctl is-enabled firewalld &> /dev/null; then
            systemctl enable firewalld 2>/dev/null
            if [ $? -eq 0 ]; then
                echo "防火墙服务启用成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已启用防火墙服务" >> "$log_file"
            else
                echo "警告: 防火墙服务启用失败（权限不足），跳过"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 启用防火墙服务（权限不足）" >> "$log_file"
                return 0
            fi
        else
            echo "防火墙服务已启用，跳过"
        fi
        
        if ! systemctl is-active firewalld &> /dev/null; then
            systemctl start firewalld 2>/dev/null
            if [ $? -eq 0 ]; then
                echo "防火墙服务启动成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已启动防火墙服务" >> "$log_file"
            else
                echo "警告: 防火墙服务启动失败（权限不足），跳过"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 启动防火墙服务（权限不足）" >> "$log_file"
                return 0
            fi
        else
            echo "防火墙服务已运行，跳过"
        fi
        
        # 配置SSH端口
        echo "配置防火墙SSH端口规则..."
        
        # 检查SSH端口是否已修改
        if [ ! -z "$SSH_PORT" ] && [ "$SSH_PORT" != "22" ]; then
            # 关闭默认22端口
            if firewall-cmd --permanent --remove-port=22/tcp 2>/dev/null; then
                echo "关闭默认端口22成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已关闭默认端口22" >> "$log_file"
            else
                echo "默认端口22关闭失败（权限不足），跳过"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 关闭默认端口22（权限不足）" >> "$log_file"
            fi
            
            # 开放配置的SSH端口
            if firewall-cmd --permanent --add-port="$SSH_PORT"/tcp 2>/dev/null; then
                echo "开放SSH端口 $SSH_PORT 成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已开放SSH端口 $SSH_PORT" >> "$log_file"
            else
                echo "SSH端口 $SSH_PORT 开放失败（权限不足），跳过"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 开放SSH端口 $SSH_PORT（权限不足）" >> "$log_file"
            fi
        else
            echo "SSH端口未修改或未配置，保持默认端口设置"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 提示: SSH端口未修改或未配置，保持默认端口设置" >> "$log_file"
        fi
        
        # 关闭所有其他端口
        echo "配置默认拒绝策略..."
        if firewall-cmd --permanent --set-default-zone=public 2>/dev/null; then
            echo "设置默认区域为 public 成功"
        fi
        if firewall-cmd --permanent --zone=public --set-target=DROP 2>/dev/null; then
            echo "设置默认目标为 DROP 成功"
        fi
        
        # 允许必要的服务
        if firewall-cmd --permanent --zone=public --add-service=ssh 2>/dev/null; then
            echo "添加 ssh 服务成功"
        fi
        if firewall-cmd --permanent --zone=public --add-service=dhcp 2>/dev/null; then
            echo "添加 dhcp 服务成功"
        fi
        
        # 重新加载防火墙配置
        if firewall-cmd --reload 2>/dev/null; then
            echo "防火墙配置重新加载成功"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已重新加载防火墙配置" >> "$log_file"
        else
            echo "防火墙配置重新加载失败（权限不足），跳过"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 重新加载防火墙配置（权限不足）" >> "$log_file"
        fi
    fi
}

# 系统安全加固
secure_system() {
    local log_file="$1"
    
    # 安装安全更新
    dnf update -y --security 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已安装安全更新" >> "$log_file"
    else
        echo "警告: 安全更新安装失败（权限不足），跳过"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 安装安全更新（权限不足）" >> "$log_file"
    fi
    
    # 配置密码策略
    if [ -w "/etc/login.defs" ]; then
        # 设置密码最小长度
        sed -i 's/^PASS_MIN_LEN.*/PASS_MIN_LEN 12/' /etc/login.defs 2>/dev/null
        # 设置密码过期时间
        sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS 90/' /etc/login.defs 2>/dev/null
        # 设置密码警告时间
        sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE 7/' /etc/login.defs 2>/dev/null
    else
        echo "警告: 无法修改密码策略（权限不足），跳过"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 无法修改密码策略（权限不足）" >> "$log_file"
    fi
    
    # 配置SSH安全设置
    if [ -w "/etc/ssh/sshd_config" ]; then
        # 禁用root登录
        sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config 2>/dev/null
        # 禁用密码认证（如果配置为no）
        if [ "$PASSWORD_AUTHENTICATION" = "no" ]; then
            sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config 2>/dev/null
        fi
        # 禁用X11转发
        sed -i 's/^#X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config 2>/dev/null
        # 禁用TCP端口转发
        sed -i 's/^#AllowTcpForwarding.*/AllowTcpForwarding no/' /etc/ssh/sshd_config 2>/dev/null
        # 设置登录超时
        echo "LoginGraceTime 30" >> /etc/ssh/sshd_config 2>/dev/null
        
        # 重启SSH服务
        systemctl restart sshd 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已重启SSH服务" >> "$log_file"
        else
            echo "警告: SSH服务重启失败（权限不足），跳过"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 重启SSH服务（权限不足）" >> "$log_file"
        fi
    else
        echo "警告: 无法修改SSH配置（权限不足），跳过"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 无法修改SSH配置（权限不足）" >> "$log_file"
    fi
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 系统安全加固完成" >> "$log_file"
}

# 配置Fail2ban
configure_fail2ban() {
    local log_file="$1"
    
    if [ "$INSTALL_FAIL2BAN" = "yes" ]; then
        # 检查Fail2ban是否已安装
        if ! rpm -q fail2ban &> /dev/null; then
            echo "配置EPEL仓库..."
            # 安装EPEL仓库
            dnf install -y epel-release 2>/dev/null
            if [ $? -eq 0 ]; then
                echo "EPEL仓库安装成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已安装EPEL仓库" >> "$log_file"
            else
                echo "警告: EPEL仓库安装失败，跳过Fail2ban安装"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 安装EPEL仓库" >> "$log_file"
                return 0
            fi
            
            # 安装Fail2ban
            echo "安装Fail2ban..."
            dnf install -y fail2ban 2>/dev/null
            if [ $? -eq 0 ]; then
                echo "Fail2ban安装成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已安装Fail2ban" >> "$log_file"
            else
                echo "警告: Fail2ban安装失败，跳过"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 安装Fail2ban" >> "$log_file"
                return 0
            fi
        else
            echo "Fail2ban已安装，跳过"
        fi
        
        if ! systemctl is-enabled fail2ban &> /dev/null; then
            systemctl enable fail2ban 2>/dev/null
            if [ $? -eq 0 ]; then
                echo "Fail2ban服务启用成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已启用Fail2ban服务" >> "$log_file"
            else
                echo "警告: Fail2ban服务启用失败（权限不足），跳过"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 启用Fail2ban服务（权限不足）" >> "$log_file"
                return 0
            fi
        else
            echo "Fail2ban服务已启用，跳过"
        fi
        
        if ! systemctl is-active fail2ban &> /dev/null; then
            systemctl start fail2ban 2>/dev/null
            if [ $? -eq 0 ]; then
                echo "Fail2ban服务启动成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已启动Fail2ban服务" >> "$log_file"
            else
                echo "警告: Fail2ban服务启动失败（权限不足），跳过"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 启动Fail2ban服务（权限不足）" >> "$log_file"
                return 0
            fi
        else
            echo "Fail2ban服务已运行，跳过"
        fi
    fi
}




