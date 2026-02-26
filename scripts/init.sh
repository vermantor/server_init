#!/bin/bash

# 完整初始化函数
# 被 run.sh 和 auto_init.sh 共用

full_init() {
    local log_file="$1"
    
    # 自动检测网络接口
    detect_network_interface
    
    # 配置主机名
    configure_hostname "$log_file"
    
    # 配置网络
    configure_network "$log_file"
    
    # 配置SSH端口
    configure_ssh_port "$log_file"
    
    # 配置安全设置[配置防火墙/配置Fail2ban]
    configure_firewall "$log_file"
    configure_fail2ban "$log_file"
    
    # 添加管理员账户
    create_user "$log_file"
    
    # 配置添加的管理员账户的SSH公钥
    configure_ssh_key "$SSH_USER" "$log_file"
    
    # 禁用root密码登录
    disable_account_password "root" "$log_file"
    
    # 禁用root SSH登录
    disable_account_ssh "root" "$log_file"
    
    # 显示账户登录状态
    show_account_status
}
