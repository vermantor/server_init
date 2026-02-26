#!/bin/bash

# 网络配置模块



# 启用网卡
enable_interface() {
    local iface=$1
    # 直接尝试启用网卡，避免额外的状态检查
    ip link set $iface up 2>/dev/null
    # 短暂等待，确保网卡完全启用
    sleep 1
}

# 获取网卡MAC地址
get_mac_address() {
    local iface=$1
    ip link show $iface | grep "link/ether" | awk '{print $2}'
}

# 清理旧连接
cleanup_old_connections() {
    local iface=$1
    local mac=$2
    
    # 获取当前正在使用的连接名
    current_conn=$(nmcli -t -f NAME,DEVICE con show --active 2>/dev/null | grep ":$iface$" | cut -d: -f1)
    
    # 通过接口名查找并处理（跳过当前活跃连接）
    nmcli -t -f NAME,DEVICE con show 2>/dev/null | grep ":$iface$" | cut -d: -f1 | while read conn; do
        if [ "$conn" != "$current_conn" ]; then
            # 禁用旧连接的自动连接属性
            nmcli con mod "$conn" connection.autoconnect "no" 2>/dev/null
            # 尝试删除旧连接
            nmcli con del "$conn" 2>/dev/null || true
        else
            # 禁用当前活跃连接的自动连接属性，避免重启后冲突
            nmcli con mod "$conn" connection.autoconnect "no" 2>/dev/null
        fi
    done
    
    # 通过MAC地址查找并处理（跳过当前活跃连接）
    if [ ! -z "$mac" ]; then
        nmcli -t -f NAME,802-3-ethernet.mac-address con show 2>/dev/null | grep -i "$mac" | cut -d: -f1 | while read conn; do
            if [ "$conn" != "$current_conn" ]; then
                # 禁用旧连接的自动连接属性
                nmcli con mod "$conn" connection.autoconnect "no" 2>/dev/null
                # 尝试删除旧连接
                nmcli con del "$conn" 2>/dev/null || true
            else
                # 禁用当前活跃连接的自动连接属性，避免重启后冲突
                nmcli con mod "$conn" connection.autoconnect "no" 2>/dev/null
            fi
        done
    fi
}

# 创建网络连接
create_connection() {
    local iface=$1
    local mac=$2
    local log_file=$3
    local conn_name="eth-${iface}-new"
    
    # 检查是否存在已有的连接，如果存在则重用
    if nmcli con show "$conn_name" &>/dev/null; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 信息: 重用现有网络连接 $conn_name" >> "$log_file"
        echo "$conn_name"
        return 0
    fi
    
    # 检查连接名是否已存在，如果存在则增加计数器
    local counter=1
    while nmcli con show "eth-${iface}-new-${counter}" &>/dev/null; do
        ((counter++))
    done
    
    # 如果不存在基本连接名，则使用基本连接名
    if [ $counter -eq 1 ]; then
        conn_name="eth-${iface}-new"
    else
        conn_name="eth-${iface}-new-${counter}"
    fi
    
    # 将子网掩码转换为CIDR前缀长度
    subnet_to_cidr() {
        local mask=$1
        local cidr=0
        local octet
        for octet in $(echo $mask | tr '.' ' '); do
            case $octet in
                255) cidr=$((cidr + 8)) ;;
                254) cidr=$((cidr + 7)) ;;
                252) cidr=$((cidr + 6)) ;;
                248) cidr=$((cidr + 5)) ;;
                240) cidr=$((cidr + 4)) ;;
                224) cidr=$((cidr + 3)) ;;
                192) cidr=$((cidr + 2)) ;;
                128) cidr=$((cidr + 1)) ;;
                0) break ;;
                *) return 1 ;;
            esac
        done
        echo $cidr
    }
    
    # 计算CIDR前缀长度
    CIDR=$(subnet_to_cidr "$NETMASK")
    
    # 一次性创建连接并配置所有参数
    nmcli con add con-name "$conn_name" ifname "$iface" type ethernet \
        ipv4.method manual \
        ipv4.addresses "$IP_ADDRESS/$CIDR" \
        ipv4.gateway "$GATEWAY" \
        ipv4.dns "$DNS_SERVERS" \
        connection.autoconnect "yes" >/dev/null 2>&1
    
    # 设置MAC地址（提高稳定性）
    if [ ! -z "$mac" ]; then
        nmcli con mod "$conn_name" 802-3-ethernet.mac-address "$mac" >/dev/null 2>&1
    fi
    
    # 禁用IPv6（避免IPv6地址冲突）
    nmcli con mod "$conn_name" ipv6.method disabled >/dev/null 2>&1
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 创建网络连接 $conn_name" >> "$log_file"
    echo "$conn_name"
}

# 测试网络连接
test_network() {
    local log_file="$1"
    
    local success=0
    local total=0
    local test_hosts="8.8.8.8"
    
    for host in $test_hosts; do
        total=$((total + 1))
        if ping -c 1 -W 2 "$host" &>/dev/null; then
            success=$((success + 1))
        fi
    done
    
    if [ $success -eq 0 ] && [ $total -gt 0 ]; then
        echo "错误: 所有网络测试都失败！"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 网络测试失败" >> "$log_file"
        return 1
    elif [ $success -lt $total ]; then
        echo "警告: 部分网络测试失败，但网络已成功配置"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 信息: 部分网络测试失败，但网络已成功配置" >> "$log_file"
        return 0
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 网络测试通过" >> "$log_file"
        return 0
    fi
}

# 显示网络状态
show_network_status() {
    # 网络状态信息已记录到日志文件，不再在控制台显示
    return 0
}

# 显示网络信息（用于初始化完成后显示）
show_final_network_info() {
    echo ""
    echo "====================================================="
    echo "                    网络配置信息"
    echo "====================================================="
    
    echo ""
    echo "网络接口: $NETWORK_INTERFACE"
    echo "IP地址: $IP_ADDRESS"
    echo "子网掩码: $NETMASK"
    echo "网关: $GATEWAY"
    echo "DNS服务器: $DNS_SERVERS"
    echo "SSH端口: $SSH_PORT"
    
    # 显示活跃连接
    echo ""
    echo "活跃连接:"
    nmcli con show --active 2>/dev/null | tail -n +2 | while read line; do
        echo "  $line"
    done
    
    # 显示IP地址信息
    echo ""
    echo "IP地址信息:"
    ip -4 addr show | grep -v "127.0.0.1" | grep inet | while read line; do
        echo "  $line"
    done
    
    echo "====================================================="
}

# 配置网络
configure_network() {
    local log_file="$1"
    
    if [ ! -z "$NETWORK_INTERFACE" ] && [ ! -z "$IP_ADDRESS" ] && [ ! -z "$GATEWAY" ] && [ ! -z "$DNS_SERVERS" ]; then
        # 启用网卡
        enable_interface "$NETWORK_INTERFACE"
        
        # 获取MAC地址
        MAC=$(get_mac_address "$NETWORK_INTERFACE")
        
        # 清理旧连接
        cleanup_old_connections "$NETWORK_INTERFACE" "$MAC"
        
        # 创建新连接
        CONN_NAME=$(create_connection "$NETWORK_INTERFACE" "$MAC" "$log_file")
        
        # 显示网络状态
        show_network_status
        
        # 测试网络
        test_network "$log_file"
        local test_result=$?
        
        if [ $test_result -eq 0 ]; then
            echo "新的网络连接: $CONN_NAME 已创建，将在系统重启后自动激活"
            echo "网络配置成功！"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 信息: 新网络连接 $CONN_NAME 将在系统重启后自动激活" >> "$log_file"
        else
            echo "错误: 网络配置可能有问题，请手动检查"
        fi
    else
        echo "错误: 网络配置参数不完整，跳过网络配置"
        return 1
    fi
}
