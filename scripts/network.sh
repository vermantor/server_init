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

# 配置静态网络
configure_network() {
    local log_file="$1"
    
    if [ ! -z "$NETWORK_INTERFACE" ] && [ ! -z "$IP_ADDRESS" ] && [ ! -z "$GATEWAY" ] && [ ! -z "$DNS_SERVERS" ]; then
        # 检查网络配置是否已存在
        if [ -f "/etc/sysconfig/network-scripts/ifcfg-$NETWORK_INTERFACE" ]; then
            current_ip=$(grep -oP 'IPADDR=\K[^\n]+' /etc/sysconfig/network-scripts/ifcfg-$NETWORK_INTERFACE 2>/dev/null)
            if [ "$current_ip" = "$IP_ADDRESS" ]; then
                echo "网络接口 $NETWORK_INTERFACE 已配置为 $IP_ADDRESS，跳过"
                return
            fi
        fi
        
        # 备份原有网络配置
        if [ -f "/etc/sysconfig/network-scripts/ifcfg-$NETWORK_INTERFACE" ]; then
            cp -f "/etc/sysconfig/network-scripts/ifcfg-$NETWORK_INTERFACE" "/etc/sysconfig/network-scripts/ifcfg-$NETWORK_INTERFACE.bak"
            if [ $? -eq 0 ]; then
                echo "备份网络配置成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 备份网络配置" >> "$log_file"
            else
                echo "备份网络配置失败"
                echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 备份网络配置" >> "$log_file"
                exit 1
            fi
        fi
        
        # 生成新的网络配置
        cat > "/etc/sysconfig/network-scripts/ifcfg-$NETWORK_INTERFACE" << EOF
TYPE=Ethernet
BOOTPROTO=static
NAME=$NETWORK_INTERFACE
DEVICE=$NETWORK_INTERFACE
ONBOOT=yes
IPADDR=$IP_ADDRESS
NETMASK=$NETMASK
GATEWAY=$GATEWAY
DNS1=${DNS_SERVERS%% *}
EOF
        
        if [ $? -eq 0 ]; then
            echo "生成网络配置文件成功"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 生成网络配置文件" >> "$log_file"
        else
            echo "生成网络配置文件失败"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 生成网络配置文件" >> "$log_file"
            exit 1
        fi
        
        # 重启网络服务
        systemctl restart NetworkManager
        if [ $? -eq 0 ]; then
            echo "重启网络服务成功"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 重启网络服务" >> "$log_file"
        else
            echo "重启网络服务失败"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 重启网络服务" >> "$log_file"
            exit 1
        fi
    fi
}
