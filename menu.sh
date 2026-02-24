#!/bin/bash

# OpenCloudOS 9 服务器初始化可视化界面
# 类似于宝塔面板的bt命令

set -e

# 脚本目录
SCRIPT_DIR="$(dirname "$0")/scripts"

# 检查并设置脚本权限
check_script_permissions() {
    echo "检查脚本权限..."
    for script in "$SCRIPT_DIR"/*.sh; do
        if [ -f "$script" ]; then
            chmod +x "$script" 2>/dev/null || true
        fi
    done
    echo "脚本权限检查完成"
}

# 检查并设置脚本权限
check_script_permissions

# 加载通用函数模块
if [ -f "$SCRIPT_DIR/common.sh" ]; then
    source "$SCRIPT_DIR/common.sh"
else
    echo "错误: 找不到通用函数模块 $SCRIPT_DIR/common.sh"
    exit 1
fi

# 加载语言配置模块
if [ -f "$SCRIPT_DIR/language_config.sh" ]; then
    source "$SCRIPT_DIR/language_config.sh"
else
    echo "错误: 找不到语言配置模块 $SCRIPT_DIR/language_config.sh"
    exit 1
fi

# 加载Git检查模块
if [ -f "$SCRIPT_DIR/git_check.sh" ]; then
    source "$SCRIPT_DIR/git_check.sh"
else
    echo "错误: 找不到Git检查模块 $SCRIPT_DIR/git_check.sh"
    exit 1
fi

# 加载网络配置模块
if [ -f "$SCRIPT_DIR/network.sh" ]; then
    source "$SCRIPT_DIR/network.sh"
else
    echo "错误: 找不到网络配置模块 $SCRIPT_DIR/network.sh"
    exit 1
fi

# 加载SSH配置模块
if [ -f "$SCRIPT_DIR/ssh.sh" ]; then
    source "$SCRIPT_DIR/ssh.sh"
else
    echo "错误: 找不到SSH配置模块 $SCRIPT_DIR/ssh.sh"
    exit 1
fi

# 加载安全配置模块
if [ -f "$SCRIPT_DIR/security.sh" ]; then
    source "$SCRIPT_DIR/security.sh"
else
    echo "错误: 找不到安全配置模块 $SCRIPT_DIR/security.sh"
    exit 1
fi

# 检查root权限
check_root

# 定义日志文件
LOG_FILE="init.log"
touch "$LOG_FILE"

# 清屏函数
clear_screen() {
    clear
}

# 显示标题
show_title() {
    clear_screen
    echo "====================================================="
    echo "      OpenCloudOS 9 服务器初始化可视化界面"
    echo "====================================================="
    echo ""
}

# 显示菜单
show_menu() {
    show_title
    echo "请选择要执行的操作:"
    echo ""
    echo "1. 执行完整初始化 (推荐)"
    echo "2. 配置语言支持"
    echo "3. 配置主机名"
    echo "4. 配置网络"
    echo "5. 配置SSH"
    echo "6. 配置安全设置"
    echo "7. 配置用户权限"
    echo "8. 配置Git"
    echo "9. 查看执行日志"
    echo "10. 退出"
    echo ""
    read -p "请输入选项 [1-10]: " choice
    echo ""
    return $choice
}

# 执行完整初始化
exec_full_init() {
    show_title
    echo "正在执行完整初始化..."
    echo ""
    
    # 配置语言支持
    configure_language "$LOG_FILE"
    check_git "$LOG_FILE"
    
    # 加载配置文件
    load_config
    
    # 自动检测网络接口
    detect_network_interface
    
    # 配置主机名
    configure_hostname "$LOG_FILE"
    
    # 配置网络
    configure_network "$LOG_FILE"
    
    # 配置SSH端口
    configure_ssh_port "$LOG_FILE"
    
    # 生成SSH密钥对
    generate_ssh_keys "$LOG_FILE"
    
    # 配置SSH安全设置
    configure_ssh_security "$LOG_FILE"
    
    # 配置防火墙
    configure_firewall "$LOG_FILE"
    
    # 配置Fail2ban
    configure_fail2ban "$LOG_FILE"
    
    echo ""
    echo "====================================================="
    echo "初始化完成！"
    echo "请检查 $LOG_FILE 查看详细执行日志"
    echo "====================================================="
    read -p "按 Enter 键返回菜单..."
}

# 配置语言支持
exec_language_config() {
    show_title
    echo "正在配置语言支持..."
    echo ""
    
    configure_language "$LOG_FILE"
    check_git "$LOG_FILE"
    
    echo ""
    echo "====================================================="
    echo "语言支持配置完成！"
    echo "====================================================="
    read -p "按 Enter 键返回菜单..."
}

# 配置主机名
exec_hostname_config() {
    show_title
    echo "正在配置主机名..."
    echo ""
    
    # 加载配置文件
    load_config
    
    configure_hostname "$LOG_FILE"
    
    echo ""
    echo "====================================================="
    echo "主机名配置完成！"
    echo "====================================================="
    read -p "按 Enter 键返回菜单..."
}

# 配置网络
exec_network_config() {
    show_title
    echo "正在配置网络..."
    echo ""
    
    # 加载配置文件
    load_config
    
    # 自动检测网络接口
    detect_network_interface
    
    configure_network "$LOG_FILE"
    
    echo ""
    echo "====================================================="
    echo "网络配置完成！"
    echo "====================================================="
    read -p "按 Enter 键返回菜单..."
}

# 配置SSH
exec_ssh_config() {
    show_title
    echo "正在配置SSH..."
    echo ""
    
    # 加载配置文件
    load_config
    
    # 配置SSH端口
    configure_ssh_port "$LOG_FILE"
    
    # 生成SSH密钥对
    generate_ssh_keys "$LOG_FILE"
    
    # 配置SSH安全设置
    configure_ssh_security "$LOG_FILE"
    
    echo ""
    echo "====================================================="
    echo "SSH配置完成！"
    echo "====================================================="
    read -p "按 Enter 键返回菜单..."
}

# 配置安全设置
exec_security_config() {
    show_title
    echo "正在配置安全设置..."
    echo ""
    
    # 加载配置文件
    load_config
    
    # 配置防火墙
    configure_firewall "$LOG_FILE"
    
    # 配置Fail2ban
    configure_fail2ban "$LOG_FILE"
    
    echo ""
    echo "====================================================="
    echo "安全设置配置完成！"
    echo "====================================================="
    read -p "按 Enter 键返回菜单..."
}

# 配置Git
exec_git_config() {
    show_title
    echo "正在配置Git..."
    echo ""
    
    check_git "$LOG_FILE"
    
    echo ""
    echo "====================================================="
    echo "Git配置完成！"
    echo "====================================================="
    read -p "按 Enter 键返回菜单..."
}

# 配置用户权限
exec_user_permissions_config() {
    show_title
    echo "正在配置用户权限..."
    echo ""
    
    # 加载配置文件
    load_config
    
    configure_user_permissions "$LOG_FILE"
    
    echo ""
    echo "====================================================="
    echo "用户权限配置完成！"
    echo "====================================================="
    read -p "按 Enter 键返回菜单..."
}

# 查看执行日志
exec_view_log() {
    show_title
    echo "执行日志内容:"
    echo "====================================================="
    
    if [ -f "$LOG_FILE" ]; then
        cat "$LOG_FILE"
    else
        echo "日志文件不存在"
    fi
    
    echo "====================================================="
    read -p "按 Enter 键返回菜单..."
}

# 主循环
main() {
    while true; do
        show_menu
        choice=$?
        
        case $choice in
            1)
                exec_full_init
                ;;
            2)
                exec_language_config
                ;;
            3)
                exec_hostname_config
                ;;
            4)
                exec_network_config
                ;;
            5)
                exec_ssh_config
                ;;
            6)
                exec_security_config
                ;;
            7)
                exec_user_permissions_config
                ;;
            8)
                exec_git_config
                ;;
            9)
                exec_view_log
                ;;
            10)
                show_title
                echo "感谢使用 OpenCloudOS 9 服务器初始化工具！"
                echo ""
                exit 0
                ;;
            *)
                echo "无效的选项，请重新输入！"
                read -p "按 Enter 键继续..."
                ;;
        esac
    done
}

# 执行主函数
main
