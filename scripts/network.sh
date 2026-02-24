#!/bin/bash

# 网络配置模块

# 配置主机名
configure_hostname() {
    local log_file="$1"
    
    if [ ! -z "$HOSTNAME" ]; then
        # 检查主机名是否已设置
        current_hostname=$(hostname)
        if [ "$current_hostname" != "$HOSTNAME" ]; then
            hostnamectl set-hostname "$HOSTNAME"
            if [ $? -eq 0 ]; then
                echo "修改主机名成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 修改主机名为 $HOSTNAME" >> "$log_file"
            else
                echo "修改主机名失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 修改主机名" >> "$log_file"
                exit 1
            fi
            
            echo "$HOSTNAME" > /etc/hostname
            if [ $? -eq 0 ]; then
                echo "更新/etc/hostname文件成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 更新/etc/hostname文件" >> "$log_file"
            else
                echo "更新/etc/hostname文件失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 更新/etc/hostname文件" >> "$log_file"
                exit 1
            fi
        else
            echo "主机名已设置为 $HOSTNAME，跳过"
        fi
    fi
}

# 启用网卡
enable_interface() {
    local iface=$1
    local state=$(ip link show $iface | grep "state" | awk '{print $9}')
    
    if [ "$state" = "DOWN" ]; then
        echo "正在启用网卡 $iface..."
        ip link set $iface up
        sleep 2
    fi
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
    
    # 创建基本连接
    nmcli con add con-name "$conn_name" ifname "$iface" type ethernet
    
    # 设置MAC地址（提高稳定性）
    if [ ! -z "$mac" ]; then
        nmcli con mod "$conn_name" 802-3-ethernet.mac-address "$mac"
    fi
    
    # 设置自动连接
    nmcli con mod "$conn_name" connection.autoconnect "yes"
    
    # 配置静态IP
    echo "配置静态IP: $IP_ADDRESS"
    nmcli con mod "$conn_name" ipv4.addresses "$IP_ADDRESS/$NETMASK"
    nmcli con mod "$conn_name" ipv4.gateway "$GATEWAY"
    nmcli con mod "$conn_name" ipv4.dns "$DNS_SERVERS"
    nmcli con mod "$conn_name" ipv4.method manual
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 创建网络连接 $conn_name" >> "$log_file"
    echo "$conn_name"
}

# 测试网络连接
test_network() {
    local log_file="$1"
    echo "测试网络连通性..."
    
    local success=0
    local total=0
    local test_hosts="8.8.8.8 baidu.com"
    
    for host in $test_hosts; do
        total=$((total + 1))
        if ping -c 2 -W 3 "$host" &>/dev/null; then
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
        echo "部分网络测试失败"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 警告: 部分网络测试失败" >> "$log_file"
        return 2
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
        if nmcli con up "$CONN_NAME" &>/dev/null; then
            echo "网卡 $NETWORK_INTERFACE 连接成功！"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 激活网络连接 $CONN_NAME" >> "$log_file"
        else
            echo "网卡 $NETWORK_INTERFACE 连接失败！"
            echo "尝试备用连接方法..."
            nmcli dev connect "$NETWORK_INTERFACE" &>/dev/null
            
            if [ $? -eq 0 ]; then
                echo "备用方法连接成功！"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 备用方法连接网络" >> "$log_file"
            else
                echo "备用方法也失败了"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 网络连接失败" >> "$log_file"
                exit 1
            fi
        fi
        
        # 显示网络状态
        show_network_status
        
        # 测试网络
        test_network "$log_file"
        local test_result=$?
        
        echo ""
        if [ $test_result -eq 0 ]; then
            echo "网络配置成功！"
        elif [ $test_result -eq 2 ]; then
            echo "网络部分可用，可能需要手动检查DNS配置"
        else
            echo "网络配置可能有问题，请手动检查"
        fi
    fi
}
