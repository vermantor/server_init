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
    # if [ -w "/etc/login.defs" ]; then
    #     # 设置密码最小长度
    #     sed -i 's/^PASS_MIN_LEN.*/PASS_MIN_LEN 12/' /etc/login.defs 2>/dev/null
    #     # 设置密码过期时间
    #     sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS 90/' /etc/login.defs 2>/dev/null
    #     # 设置密码警告时间
    #     sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE 7/' /etc/login.defs 2>/dev/null
    # else
    #     echo "警告: 无法修改密码策略（权限不足），跳过"
    #     echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 无法修改密码策略（权限不足）" >> "$log_file"
    # fi
    
    # 配置SSH安全设置
    if [ -w "/etc/ssh/sshd_config" ]; then
        # 禁用root登录
        # d -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config 2>/dev/null
        # 禁用密码认证（如果配置为no）
        if [ "$PASSWORD_AUTHENTICATION" = "no" ]; then
            sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config 2>/dev/null
        fi
        # 禁用X11转发
        sed -i 's/^#X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config 2>/dev/null
        # 禁用TCP端口转发
        sed -i 's/^#AllowTcpForwarding.*/AllowTcpForwarding no/' /etc/ssh/sshd_config 2>/dev/null
        # 设置登录超时
        if grep -q "^LoginGraceTime" /etc/ssh/sshd_config 2>/dev/null; then
            sed -i 's/^LoginGraceTime.*/LoginGraceTime 30/' /etc/ssh/sshd_config 2>/dev/null
        else
            # 在Match块之前添加LoginGraceTime指令
            sed -i '/^Match/i\LoginGraceTime 30' /etc/ssh/sshd_config 2>/dev/null
        fi
        
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
    
    # 获取当前工作目录
    local current_dir="$(pwd)"
    local source_dir="$current_dir/source"
    
    if [ "$INSTALL_FAIL2BAN" = "yes" ]; then
        # 检查Fail2ban是否已安装（通过命令是否存在来检查）
        if ! command -v fail2ban-server &> /dev/null; then
            echo "从source文件夹安装Fail2ban..."
            # 解压fail2ban压缩包
            if [ -f "$source_dir/fail2ban-master.zip" ]; then
                unzip -q -o "$source_dir/fail2ban-master.zip" -d /tmp/
                if [ $? -eq 0 ]; then
                    echo "Fail2ban压缩包解压成功"
                    # 进入解压后的目录
                    cd /tmp/fail2ban-master || {
                        echo "警告: 进入fail2ban目录失败，跳过安装"
                        echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 进入fail2ban目录"
                        return 0
                    }
                    # 安装fail2ban
                    python3 setup.py install 2>/dev/null
                    if [ $? -eq 0 ]; then
                        echo "Fail2ban安装成功"
                        echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 已安装Fail2ban" >> "$log_file"
                        
                        # 创建systemd服务单元文件
                        echo "创建systemd服务单元文件..."
                        cat > /etc/systemd/system/fail2ban.service << EOF
[Unit]
Description=Fail2Ban Service
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/fail2ban-server -b
ExecStop=/usr/local/bin/fail2ban-client stop
ExecReload=/usr/local/bin/fail2ban-client reload
PIDFile=/run/fail2ban/fail2ban.pid
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
                        if [ $? -eq 0 ]; then
                            echo "systemd服务单元文件创建成功"
                            echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 创建systemd服务单元文件" >> "$log_file"
                            
                            # 重新加载systemd配置
                            systemctl daemon-reload 2>/dev/null
                            if [ $? -eq 0 ]; then
                                echo "systemd配置重新加载成功"
                                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 重新加载systemd配置" >> "$log_file"
                            else
                                echo "警告: systemd配置重新加载失败（权限不足）"
                                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 重新加载systemd配置（权限不足）" >> "$log_file"
                            fi
                            
                            # 添加fail2ban默认配置规则
                            echo "添加fail2ban默认配置规则..."
                            cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1 192.168.1.0/24
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = $SSH_PORT
logpath = /var/log/secure
EOF
                            if [ $? -eq 0 ]; then
                                echo "fail2ban默认配置规则添加成功"
                                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 添加fail2ban默认配置规则" >> "$log_file"
                            else
                                echo "警告: fail2ban默认配置规则添加失败（权限不足）"
                                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 添加fail2ban默认配置规则（权限不足）" >> "$log_file"
                            fi
                        else
                            echo "警告: systemd服务单元文件创建失败（权限不足）"
                            echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 创建systemd服务单元文件（权限不足）" >> "$log_file"
                        fi
                    else
                        echo "警告: Fail2ban安装失败"
                        echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 安装Fail2ban" >> "$log_file"
                        return 0
                    fi
                else
                    echo "警告: Fail2ban压缩包解压失败，跳过安装"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 解压Fail2ban压缩包" >> "$log_file"
                    return 0
                fi
            else
                echo "警告: Fail2ban压缩包不存在，跳过安装"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: Fail2ban压缩包不存在" >> "$log_file"
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




