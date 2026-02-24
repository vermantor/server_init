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
