#!/bin/bash

# 通用函数模块

# 检测是否支持中文显示
check_chinese_support() {
    if locale -a | grep -q 'zh_CN.UTF-8' || rpm -q glibc-langpack-zh &> /dev/null; then
        return 0  # 支持中文
    else
        return 1  # 不支持中文
    fi
}

# 函数: 执行命令并记录日志
exec_cmd() {
    local cmd="$1"
    local desc="$2"
    local log_file="$3"
    local ignore_error="$4"
    
    echo "$desc..."
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 执行: $desc" >> "$log_file"
    
    if bash -c "$cmd"; then
        echo "$desc 成功"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: $desc" >> "$log_file"
        return 0
    else
        echo "$desc 失败"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: $desc" >> "$log_file"
        if [ "$ignore_error" != "true" ]; then
            return 1
        else
            echo "忽略错误，继续执行..."
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 警告: 忽略 $desc 失败，继续执行" >> "$log_file"
            return 0
        fi
    fi
}

# 函数: 检查命令是否存在
check_command() {
    local cmd="$1"
    if command -v "$cmd" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# 函数: 错误处理
handle_error() {
    local error_msg="$1"
    local log_file="$2"
    local exit_on_error="$3"
    
    echo "错误: $error_msg"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 错误: $error_msg" >> "$log_file"
    
    if [ "$exit_on_error" = "true" ]; then
        echo "脚本将退出..."
        exit 1
    else
        echo "继续执行后续步骤..."
        return 1
    fi
}

# 函数: 信息提示
info_msg() {
    local msg="$1"
    local log_file="$2"
    
    echo "信息: $msg"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 信息: $msg" >> "$log_file"
}

# 函数: 警告提示
warning_msg() {
    local msg="$1"
    local log_file="$2"
    
    echo "警告: $msg"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 警告: $msg" >> "$log_file"
}

# 函数: 显示进度条
show_progress() {
    local current="$1"
    local total="$2"
    local title="$3"
    
    local percentage=$((current * 100 / total))
    local bar_length=50
    local filled_length=$((percentage * bar_length / 100))
    local empty_length=$((bar_length - filled_length))
    
    local filled=$(printf "#%.0s" $(seq 1 $filled_length))
    local empty=$(printf "-%.0s" $(seq 1 $empty_length))
    
    printf "\r%s: [%s%s] %d%%" "$title" "$filled" "$empty" "$percentage"
    
    if [ $current -eq $total ]; then
        echo ""
    fi
}

# 函数: 显示操作开始
show_operation_start() {
    local operation="$1"
    local log_file="$2"
    
    echo ""
    echo "====================================================="
    echo "开始: $operation"
    echo "====================================================="
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始: $operation" >> "$log_file"
}

# 函数: 显示操作完成
show_operation_complete() {
    local operation="$1"
    local log_file="$2"
    
    echo "====================================================="
    echo "完成: $operation"
    echo "====================================================="
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 完成: $operation" >> "$log_file"
    echo ""
}

# 加载配置文件
load_config() {
    local config_file=".env"
    local example_file=".env.example"
    
    # 检查.env文件是否存在
    if [ ! -f "$config_file" ]; then
        if [ -f "$example_file" ]; then
            echo "未找到.env文件，正在从.env.example创建..."
            cp "$example_file" "$config_file"
            echo "请编辑.env文件设置您的配置，然后重新运行脚本"
            exit 1
        else
            echo "错误: 未找到.env或.env.example文件"
            exit 1
        fi
    fi
    
    # 加载.env文件
    echo "加载配置文件..."
    source "$config_file"
    
    # 设置默认值
    : ${HOSTNAME:=server01}
    : ${IP_ADDRESS:=192.168.1.100}
    : ${NETMASK:=255.255.255.0}
    : ${GATEWAY:=192.168.1.1}
    : ${DNS_SERVERS:="192.168.1.1 61.139.2.69"}
    : ${SSH_PORT:=8888}
    : ${SSH_USER:=admin}
    : ${PASSWORD_AUTHENTICATION:=no}
    : ${ENABLE_FIREWALL:=yes}
    : ${INSTALL_FAIL2BAN:=yes}
    
    # 验证配置
    validate_config
}

# 验证配置
validate_config() {
    echo "验证配置..."
    
    # 验证SSH端口
    if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || [ "$SSH_PORT" -lt 1 ] || [ "$SSH_PORT" -gt 65535 ]; then
        echo "警告: SSH端口配置无效，使用默认值8888"
        SSH_PORT=8888
    fi
    
    # 验证IP地址
    if ! [[ "$IP_ADDRESS" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "警告: IP地址配置无效，使用默认值192.168.1.100"
        IP_ADDRESS=192.168.1.100
    fi
    
    # 验证网关地址
    if ! [[ "$GATEWAY" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "警告: 网关地址配置无效，使用默认值192.168.1.1"
        GATEWAY=192.168.1.1
    fi
    
    # 验证主机名
    if [ -z "$HOSTNAME" ]; then
        echo "警告: 主机名未配置，使用默认值server01"
        HOSTNAME=server01
    fi
    
    # 验证SSH用户名
    if [ -z "$SSH_USER" ]; then
        echo "警告: SSH用户名未配置，使用默认值admin"
        SSH_USER=admin
    fi
    
    # 导出配置变量
    export HOSTNAME
    export IP_ADDRESS
    export NETMASK
    export GATEWAY
    export DNS_SERVERS
    export SSH_PORT
    export SSH_USER
    export PASSWORD_AUTHENTICATION
    export ENABLE_FIREWALL
    export INSTALL_FAIL2BAN
    
    echo "配置验证完成"
}

# 自动检测网络接口
detect_network_interface() {
    if [ -z "$NETWORK_INTERFACE" ]; then
        echo "正在自动检测网络接口..."
        # 参考 server_net_reset.sh 中的检测方法
        interfaces=""
        
        # 使用nmcli获取
        if command -v nmcli &> /dev/null; then
            interfaces=$(nmcli -t -f DEVICE,TYPE dev status 2>/dev/null | grep ":ethernet" | cut -d: -f1)
        fi
        
        # 如果nmcli没找到，使用ip命令
        if [ -z "$interfaces" ]; then
            interfaces=$(ip -o link show | grep -v "lo:" | grep "state" | awk -F': ' '{print $2}' | grep -E "^e|^en" | head -5)
        fi
        
        # 去重
        interfaces=$(echo "$interfaces" | sort -u | tr '\n' ' ')
        
        if [ -z "$interfaces" ]; then
            echo "没有找到可用的以太网卡！"
            echo "请检查网络连接并手动在.env文件中设置NETWORK_INTERFACE"
            exit 1
        fi
        
        # 取当前正在使用的网络接口（有IP地址的接口）
        # 优先选择有IP地址的接口
        active_interface=""
        for iface in $interfaces; do
            if ip -4 addr show "$iface" | grep -q "inet "; then
                active_interface="$iface"
                break
            fi
        done
        
        # 如果没有找到有IP的接口，取第一个可用接口
        if [ -z "$active_interface" ]; then
            active_interface=$(echo "$interfaces" | awk '{print $1}')
        fi
        
        NETWORK_INTERFACE="$active_interface"
        echo "自动检测到网络接口: $NETWORK_INTERFACE"
    fi
    
    # 导出网络接口变量，使其在调用脚本中可用
    export NETWORK_INTERFACE
}

# 检查root权限
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "错误: 请以root权限执行此脚本"
        exit 1
    fi
}
