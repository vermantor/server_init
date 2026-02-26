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
    
    echo "清理网卡 $iface 的旧连接..."
    
    # 通过接口名查找并删除
    nmcli -t -f NAME,DEVICE con show 2>/dev/null | grep ":$iface$" | cut -d: -f1 | while read conn; do
        echo "删除旧连接(接口匹配): $conn"
        nmcli con del "$conn" 2>/dev/null
    done
    
    # 通过MAC地址查找并删除
    if [ ! -z "$mac" ]; then
        nmcli -t -f NAME,802-3-ethernet.mac-address con show 2>/dev/null | grep -i "$mac" | cut -d: -f1 | while read conn; do
            echo "删除旧连接(MAC匹配): $conn"
            nmcli con del "$conn" 2>/dev/null
        done
    fi
}

# 创建网络连接
create_connection() {
    local iface=$1
    local mac=$2
    local log_file=$3
    local conn_name="eth-${iface}"
    
    # 检查连接名是否已存在
    local counter=1
    while nmcli con show "$conn_name" &>/dev/null; do
        conn_name="eth-${iface}-${counter}"
        ((counter++))
    done
    
    echo "创建新连接: $conn_name"
    
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
        connection.autoconnect "yes"
    
    # 设置MAC地址（提高稳定性）
    if [ ! -z "$mac" ]; then
        nmcli con mod "$conn_name" 802-3-ethernet.mac-address "$mac"
    fi
    
    # 禁用IPv6（避免IPv6地址冲突）
    nmcli con mod "$conn_name" ipv6.method disabled
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 创建网络连接 $conn_name" >> "$log_file"
    echo "$conn_name"
}

# 测试网络连接
test_network() {
    local log_file="$1"
    echo "测试网络连通性..."
    
    local success=0
    local total=0
    local test_hosts="8.8.8.8"
    
    for host in $test_hosts; do
        total=$((total + 1))
        if ping -c 1 -W 2 "$host" &>/dev/null; then
            echo "可以ping通: $host"
            success=$((success + 1))
        else
            echo "无法ping通: $host"
        fi
    done
    
    if [ $success -eq 0 ] && [ $total -gt 0 ]; then
        echo "所有网络测试都失败！"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 网络测试失败" >> "$log_file"
        return 1
    elif [ $success -lt $total ]; then
        echo "部分网络测试失败，但网络已成功配置"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 信息: 部分网络测试失败，但网络已成功配置" >> "$log_file"
        return 0
    else
        echo "所有网络测试通过"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 网络测试通过" >> "$log_file"
        return 0
    fi
}

# 显示网络状态
show_network_status() {
    echo ""
    echo "====================================================="
    echo "                    网络状态报告"
    echo "====================================================="
    
    echo ""
    echo "活跃连接:"
    nmcli con show --active 2>/dev/null | tail -n +2 | while read line; do
        echo "  $line"
    done
    
    echo ""
    echo "IP地址信息:"
    ip -4 addr show | grep -v "127.0.0.1" | grep inet | while read line; do
        echo "  $line"
    done
    
    echo ""
    echo "路由信息:"
    ip route show | grep default | while read line; do
        echo "  $line"
    done
    
    echo ""
    echo "DNS配置:"
    cat /etc/resolv.conf | grep nameserver | while read line; do
        echo "  $line"
    done
    
    echo "====================================================="
}

# 配置网络
configure_network() {
    local log_file="$1"
    
    if [ ! -z "$NETWORK_INTERFACE" ] && [ ! -z "$IP_ADDRESS" ] && [ ! -z "$GATEWAY" ] && [ ! -z "$DNS_SERVERS" ]; then
        echo "正在配置网络..."
        
        # 启用网卡
        enable_interface "$NETWORK_INTERFACE"
        
        # 获取MAC地址
        MAC=$(get_mac_address "$NETWORK_INTERFACE")
        echo "网卡 $NETWORK_INTERFACE 的MAC地址: $MAC"
        
        # 清理旧连接
        cleanup_old_connections "$NETWORK_INTERFACE" "$MAC"
        
        # 创建新连接
        CONN_NAME=$(create_connection "$NETWORK_INTERFACE" "$MAC" "$log_file")
        
        # 激活连接
        echo "激活连接 $CONN_NAME..."
        local max_attempts=3
        local attempt=1
        local connect_success=false
        
        while [ $attempt -le $max_attempts ]; do
            if nmcli con up "$CONN_NAME" &>/dev/null; then
                echo "网卡 $NETWORK_INTERFACE 连接成功！"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 激活网络连接 $CONN_NAME" >> "$log_file"
                connect_success=true
                break
            else
                echo "网卡 $NETWORK_INTERFACE 连接失败 (尝试 $attempt/$max_attempts)！"
                echo "尝试备用连接方法..."
                nmcli dev connect "$NETWORK_INTERFACE" &>/dev/null
                
                if [ $? -eq 0 ]; then
                    echo "备用方法连接成功！"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 备用方法连接网络" >> "$log_file"
                    connect_success=true
                    break
                fi
            fi
            attempt=$((attempt + 1))
            sleep 2
        done
        
        if [ "$connect_success" = "false" ]; then
            echo "所有连接方法都失败了"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 网络连接失败" >> "$log_file"
            return 1
        fi
        
        # 等待网络稳定
        echo "等待网络稳定..."
        sleep 3
        
        # 显示网络状态
        show_network_status
        
        # 测试网络
        test_network "$log_file"
        local test_result=$?
        
        echo ""
        if [ $test_result -eq 0 ]; then
            echo "网络配置成功！"
        else
            echo "网络配置可能有问题，请手动检查"
        fi
    else
        echo "网络配置参数不完整，跳过网络配置"
        return 1
    fi
}
