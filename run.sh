#!/bin/bash

# OpenCloudOS 9 服务器初始化可视化界面
# 类似于宝塔面板的bt命令

set -e

# 脚本目录
SCRIPT_DIR="$(dirname "$0")/scripts"

# 检查并设置脚本权限
check_script_permissions() {
    echo "检查脚本权限..."
    # 设置scripts目录下所有sh文件的权限
    for script in "$SCRIPT_DIR"/*.sh; do
        if [ -f "$script" ]; then
            chmod +x "$script" 2>/dev/null || true
        fi
    done
    # 设置项目根目录下pull.sh文件的权限
    if [ -f "$(dirname "$0")/pull.sh" ]; then
        chmod +x "$(dirname "$0")/pull.sh" 2>/dev/null || true
    fi
    echo "脚本权限检查完成"
}

# 检查并设置脚本权限
check_script_permissions






# 加载脚本目录下的所有模块
echo "加载配置模块..."
for script in "$SCRIPT_DIR"/*.sh; do
    if [ -f "$script" ] && [ "$(basename "$script")" != "main.sh" ]; then
        echo "加载模块: $(basename "$script")"
        source "$script"
    fi
done
echo "模块加载完成"

# 检查root权限
check_root

# 加载配置文件
load_config

# 定义日志文件
LOG_DIR="logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/init_$(date '+%Y%m%d_%H%M%S').log"
touch "$LOG_FILE"
# 创建符号链接指向最新的日志文件
ln -sf "$LOG_FILE" "$LOG_DIR/latest.log"
echo "日志文件: $LOG_FILE"
echo "最新日志链接: $LOG_DIR/latest.log"

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
    echo "2. 配置主机名"
    echo "3. 配置网络"
    echo "4. 添加管理员账户[添加账户/配置管理权限]"
    echo "5. 配置添加的管理员账户的SSH公钥"
    echo "6. 配置SSH端口[修改默认的22端口]"
    echo "7. 配置安全设置[配置防火墙/配置Fail2ban]"
    echo "8. 禁用root密码登录"
    echo "9. 禁用root SSH登录"
    echo "10. 允许root密码登录"
    echo "11. 允许root SSH登录"
    echo "12. 允许管理员密码登录"
    echo "13. 禁止管理员密码登录"
    echo "14. 允许管理员SSH登录"
    echo "15. 禁止管理员SSH登录"
    echo "16. 查看执行日志"
    echo "17. 备份系统配置"
    echo "18. 恢复系统配置"
    echo "19. 退出"
    echo ""
}

# 执行完整初始化
exec_full_init() {
    show_title
    echo "正在执行完整初始化..."
    echo ""
    
    # 调用共用的完整初始化函数
    full_init "$LOG_FILE"
    local user_success=$?
    
    echo ""
    echo "====================================================="
    echo "初始化完成！"
    echo "请检查 $LOG_FILE 查看详细执行日志"
    echo "====================================================="
    echo ""
    
    if [ $user_success -eq 0 ]; then
        echo "重要提示:"
        echo "1. 请使用新创建的管理员账户登录服务器"
        echo "2. 首次登录时系统会要求您修改初始密码，初始密码为 ChangeMe123!"
        echo "3. 请设置一个强密码，包含大小写字母、数字和特殊字符"
        echo "4. 登录命令: ssh $SSH_USER@服务器IP地址 -p $SSH_PORT"
        echo ""
        echo "初始密码已记录在 $LOG_FILE 中，请查看并妥善保管"
    else
        echo "警告:"
        echo "1. 管理员账户创建失败或未具有sudo权限"
        echo "2. 请检查 $LOG_FILE 查看详细错误信息"
        echo "3. 您可能需要手动创建管理员账户并配置权限"
        echo "4. root账户登录已被禁用，请确保您有其他登录方式"
    fi
    echo ""
    read -p "按 Enter 键返回菜单..."
}



# 配置主机名
exec_hostname_config() {
    show_title
    echo "正在配置主机名..."
    echo ""
    
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
    
    # 自动检测网络接口
    detect_network_interface
    
    configure_network "$LOG_FILE"
    
    echo ""
    echo "====================================================="
    echo "网络配置完成！"
    echo "====================================================="
    read -p "按 Enter 键返回菜单..."
}

# 配置SSH端口
exec_ssh_port_config() {
    show_title
    echo "正在配置SSH端口..."
    echo ""
    
    # 配置SSH端口
    configure_ssh_port "$LOG_FILE"
    
    echo ""
    echo "====================================================="
    echo "SSH端口配置完成！"
    echo "====================================================="
    read -p "按 Enter 键返回菜单..."
}

# 配置安全设置
exec_security_config() {
    show_title
    echo "正在配置安全设置..."
    echo ""
    
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



# 添加管理员账户
exec_user_permissions_config() {
    show_title
    echo "正在添加管理员账户..."
    echo ""
    
    create_user "$LOG_FILE"
    
    echo ""
    echo "====================================================="
    echo "管理员账户添加完成！"
    echo "====================================================="
    read -p "按 Enter 键返回菜单..."
}

# 查看执行日志
exec_view_log() {
    show_title
    echo "执行日志内容:"
    echo "====================================================="
    
    if [ -f "$LOG_DIR/latest.log" ]; then
        echo "查看最新日志文件: $LOG_DIR/latest.log"
        echo ""
        cat "$LOG_DIR/latest.log"
    elif [ -f "$LOG_FILE" ]; then
        echo "查看当前日志文件: $LOG_FILE"
        echo ""
        cat "$LOG_FILE"
    else
        echo "日志文件不存在"
        echo ""
        echo "可用的日志文件:"
        ls -la "$LOG_DIR"/*.log 2>/dev/null || echo "无日志文件"
    fi
    
    echo "====================================================="
    read -p "按 Enter 键返回菜单..."
}

# 备份系统配置
exec_backup_config() {
    show_title
    echo "正在备份系统配置..."
    echo ""
    
    backup_config "$LOG_FILE"
    local backup_result=$?
    
    echo ""
    echo "====================================================="
    if [ $backup_result -eq 0 ]; then
        echo "系统配置备份成功！"
    else
        echo "系统配置备份失败！"
    fi
    echo "====================================================="
    read -p "按 Enter 键返回菜单..."
}

# 恢复系统配置
exec_restore_config() {
    show_title
    echo "恢复系统配置"
    echo "====================================================="
    
    # 列出可用的备份
    list_backups
    echo ""
    
    read -p "请输入要恢复的备份文件路径: " backup_file
    
    if [ -f "$backup_file" ]; then
        restore_config "$LOG_FILE" "$backup_file"
        local restore_result=$?
        
        echo ""
        echo "====================================================="
        if [ $restore_result -eq 0 ]; then
            echo "系统配置恢复成功！"
            echo "注意: 部分配置可能需要重启才能生效"
        else
            echo "系统配置恢复失败！"
        fi
        echo "====================================================="
    else
        echo ""
        echo "错误: 备份文件不存在"
    fi
    
    read -p "按 Enter 键返回菜单..."
}

# 禁用root账户登录
exec_disable_root() {
    show_title
    echo "正在禁用root账户登录权限..."
    echo ""
    echo "警告: 此操作将禁用root账户登录，请确保已创建并验证了新的管理员账户！"
    echo ""
    read -p "确认执行此操作吗？ (y/n): " confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        disable_root_login "$LOG_FILE"
        
        echo ""
        echo "====================================================="
        echo "root账户登录权限已禁用！"
        echo "请使用新创建的账户进行后续操作"
        echo "====================================================="
        
        # 显示账户状态
        show_account_status
    else
        echo "操作已取消"
    fi
    
    read -p "按 Enter 键返回菜单..."
}

# 禁用root密码登录
exec_disable_root_password() {
    show_title
    echo "正在禁用root密码登录..."
    echo ""
    echo "警告: 此操作将禁用root密码登录，请确保已创建并验证了新的管理员账户！"
    echo ""
    read -p "确认执行此操作吗？ (y/n): " confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        disable_account_password "root" "$LOG_FILE"
        
        echo ""
        echo "====================================================="
        echo "root密码登录已禁用！"
        echo "====================================================="
        
        # 显示账户状态
        show_account_status
    else
        echo "操作已取消"
    fi
    
    read -p "按 Enter 键返回菜单..."
}

# 禁用root SSH登录
exec_disable_root_ssh() {
    show_title
    echo "正在禁用root SSH登录..."
    echo ""
    echo "警告: 此操作将禁用root SSH登录，请确保已创建并验证了新的管理员账户！"
    echo ""
    read -p "确认执行此操作吗？ (y/n): " confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        disable_account_ssh "root" "$LOG_FILE"
        
        echo ""
        echo "====================================================="
        echo "root SSH登录已禁用！"
        echo "====================================================="
        
        # 显示账户状态
        show_account_status
    else
        echo "操作已取消"
    fi
    
    read -p "按 Enter 键返回菜单..."
}

# 允许root密码登录
exec_allow_root_password() {
    show_title
    echo "正在允许root密码登录..."
    echo ""
    echo "警告: 此操作将允许root密码登录，可能会降低系统安全性！"
    echo ""
    read -p "确认执行此操作吗？ (y/n): " confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        allow_account_password "root" "$LOG_FILE"
        
        echo ""
        echo "====================================================="
        echo "root密码登录已允许！"
        echo "====================================================="
        
        # 显示账户状态
        show_account_status
    else
        echo "操作已取消"
    fi
    
    read -p "按 Enter 键返回菜单..."
}

# 允许root SSH登录
exec_allow_root_ssh() {
    show_title
    echo "正在允许root SSH登录..."
    echo ""
    echo "警告: 此操作将允许root SSH登录，可能会降低系统安全性！"
    echo ""
    read -p "确认执行此操作吗？ (y/n): " confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        allow_account_ssh "root" "$LOG_FILE"
        
        echo ""
        echo "====================================================="
        echo "root SSH登录已允许！"
        echo "====================================================="
        
        # 显示账户状态
        show_account_status
    else
        echo "操作已取消"
    fi
    
    read -p "按 Enter 键返回菜单..."
}

# 允许管理员密码登录
exec_allow_admin_password() {
    show_title
    echo "正在允许管理员密码登录..."
    echo ""
    
    if [ ! -z "$SSH_USER" ]; then
        echo "警告: 此操作将允许 $SSH_USER 账户密码登录！"
        echo ""
        read -p "确认执行此操作吗？ (y/n): " confirm
        
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            allow_account_password "$SSH_USER" "$LOG_FILE"
            
            echo ""
            echo "====================================================="
            echo "$SSH_USER 密码登录已允许！"
            echo "====================================================="
            
            # 显示账户状态
            show_account_status
        else
            echo "操作已取消"
        fi
    else
        echo "SSH_USER未配置，无法执行此操作"
    fi
    
    read -p "按 Enter 键返回菜单..."
}

# 禁止管理员密码登录
exec_disable_admin_password() {
    show_title
    echo "正在禁止管理员密码登录..."
    echo ""
    
    if [ ! -z "$SSH_USER" ]; then
        echo "警告: 此操作将禁止 $SSH_USER 账户密码登录，请确保已配置SSH密钥！"
        echo ""
        read -p "确认执行此操作吗？ (y/n): " confirm
        
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            disable_account_password "$SSH_USER" "$LOG_FILE"
            
            echo ""
            echo "====================================================="
            echo "$SSH_USER 密码登录已禁止！"
            echo "====================================================="
            
            # 显示账户状态
            show_account_status
        else
            echo "操作已取消"
        fi
    else
        echo "SSH_USER未配置，无法执行此操作"
    fi
    
    read -p "按 Enter 键返回菜单..."
}

# 允许管理员SSH登录
exec_allow_admin_ssh() {
    show_title
    echo "正在允许管理员SSH登录..."
    echo ""
    
    if [ ! -z "$SSH_USER" ]; then
        echo "警告: 此操作将允许 $SSH_USER 账户SSH登录！"
        echo ""
        read -p "确认执行此操作吗？ (y/n): " confirm
        
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            allow_account_ssh "$SSH_USER" "$LOG_FILE"
            
            echo ""
            echo "====================================================="
            echo "$SSH_USER SSH登录已允许！"
            echo "====================================================="
            
            # 显示账户状态
            show_account_status
        else
            echo "操作已取消"
        fi
    else
        echo "SSH_USER未配置，无法执行此操作"
    fi
    
    read -p "按 Enter 键返回菜单..."
}

# 禁止管理员SSH登录
exec_disable_admin_ssh() {
    show_title
    echo "正在禁止管理员SSH登录..."
    echo ""
    
    if [ ! -z "$SSH_USER" ]; then
        echo "警告: 此操作将禁止 $SSH_USER 账户SSH登录，请确保有其他登录方式！"
        echo ""
        read -p "确认执行此操作吗？ (y/n): " confirm
        
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            disable_account_ssh "$SSH_USER" "$LOG_FILE"
            
            echo ""
            echo "====================================================="
            echo "$SSH_USER SSH登录已禁止！"
            echo "====================================================="
            
            # 显示账户状态
            show_account_status
        else
            echo "操作已取消"
        fi
    else
        echo "SSH_USER未配置，无法执行此操作"
    fi
    
    read -p "按 Enter 键返回菜单..."
}

# 配置账户SSH公钥
exec_config_ssh_key() {
    show_title
    echo "正在配置账户SSH公钥..."
    echo ""
    
    if [ ! -z "$SSH_USER" ]; then
        configure_ssh_key "$SSH_USER" "$LOG_FILE"
    else
        echo "SSH_USER未配置，请先配置SSH_USER"
    fi
    
    echo ""
    echo "====================================================="
    echo "账户SSH公钥配置完成！"
    echo "====================================================="
    read -p "按 Enter 键返回菜单..."
}

# 主循环
main() {
    while true; do
        # 显示菜单
        show_menu
        # 直接读取用户输入
        read -p "请输入选项 [1-19]: " choice
        echo ""
        
        case $choice in
            1)
                exec_full_init
                ;;
            2)
                exec_hostname_config
                ;;
            3)
                exec_network_config
                ;;
            4)
                exec_user_permissions_config
                ;;
            5)
                exec_config_ssh_key
                ;;
            6)
                exec_ssh_port_config
                ;;
            7)
                exec_security_config
                ;;
            8)
                exec_disable_root_password
                ;;
            9)
                exec_disable_root_ssh
                ;;
            10)
                exec_allow_root_password
                ;;
            11)
                exec_allow_root_ssh
                ;;
            12)
                exec_allow_admin_password
                ;;
            13)
                exec_disable_admin_password
                ;;
            14)
                exec_allow_admin_ssh
                ;;
            15)
                exec_disable_admin_ssh
                ;;
            16)
                exec_view_log
                ;;
            17)
                exec_backup_config
                ;;
            18)
                exec_restore_config
                ;;
            19)
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
