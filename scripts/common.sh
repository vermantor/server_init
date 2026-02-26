#!/bin/bash

# 通用函数模块





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
            echo "错误: 未找到.env文件，正在从.env.example创建..."
            cp "$example_file" "$config_file"
            echo "请编辑.env文件设置您的配置，然后重新运行脚本"
            exit 1
        else
            echo "错误: 未找到.env或.env.example文件"
            exit 1
        fi
    fi
    
    # 加载.env文件
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
}

# 自动检测网络接口
detect_network_interface() {
    if [ -z "$NETWORK_INTERFACE" ]; then
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
            echo "错误: 没有找到可用的以太网卡！"
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
