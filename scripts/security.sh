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
                echo "防火墙服务启用成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已启用防火墙服务" >> "$log_file"
            else
                echo "防火墙服务启用失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 启用防火墙服务" >> "$log_file"
                return 1
            fi
        else
            echo "防火墙服务已启用，跳过"
        fi
        
        if ! systemctl is-active firewalld &> /dev/null; then
            systemctl start firewalld
            if [ $? -eq 0 ]; then
                echo "防火墙服务启动成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已启动防火墙服务" >> "$log_file"
            else
                echo "防火墙服务启动失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 启动防火墙服务" >> "$log_file"
                return 1
            fi
        else
            echo "防火墙服务已运行，跳过"
        fi
        
        # 配置SSH端口
        echo "配置防火墙SSH端口规则..."
        
        # 检查SSH端口是否已修改
        if [ ! -z "$SSH_PORT" ] && [ "$SSH_PORT" != "22" ]; then
            # 关闭默认22端口
            firewall-cmd --permanent --remove-port=22/tcp
            if [ $? -eq 0 ]; then
                echo "默认端口22关闭成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已关闭默认端口22" >> "$log_file"
            else
                echo "默认端口22关闭失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 关闭默认端口22" >> "$log_file"
            fi
            
            # 开放配置的SSH端口
            firewall-cmd --permanent --add-port="$SSH_PORT"/tcp
            if [ $? -eq 0 ]; then
                echo "SSH端口 $SSH_PORT 开放成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已开放SSH端口 $SSH_PORT" >> "$log_file"
            else
                echo "SSH端口 $SSH_PORT 开放失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 开放SSH端口 $SSH_PORT" >> "$log_file"
            fi
        else
            echo "SSH端口未修改或未配置，保持默认端口设置"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 提示: SSH端口未修改或未配置，保持默认端口设置" >> "$log_file"
        fi
        
        # 重新加载防火墙配置
        firewall-cmd --reload
        if [ $? -eq 0 ]; then
            echo "防火墙配置重新加载成功"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已重新加载防火墙配置" >> "$log_file"
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
                echo "Fail2ban安装成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已安装Fail2ban" >> "$log_file"
            else
                echo "Fail2ban安装失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 安装Fail2ban" >> "$log_file"
                return 1
            fi
        else
            echo "Fail2ban已安装，跳过"
        fi
        
        if ! systemctl is-enabled fail2ban &> /dev/null; then
            systemctl enable fail2ban
            if [ $? -eq 0 ]; then
                echo "Fail2ban服务启用成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已启用Fail2ban服务" >> "$log_file"
            else
                echo "Fail2ban服务启用失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 启用Fail2ban服务" >> "$log_file"
                return 1
            fi
        else
            echo "Fail2ban服务已启用，跳过"
        fi
        
        if ! systemctl is-active fail2ban &> /dev/null; then
            systemctl start fail2ban
            if [ $? -eq 0 ]; then
                echo "Fail2ban服务启动成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已启动Fail2ban服务" >> "$log_file"
            else
                echo "Fail2ban服务启动失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 启动Fail2ban服务" >> "$log_file"
                return 1
            fi
        else
            echo "Fail2ban服务已运行，跳过"
        fi
    fi
}




