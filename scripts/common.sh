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
    
    echo "$desc..."
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 执行: $desc" >> "$log_file"
    
    if eval "$cmd"; then
        echo "$desc 成功"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: $desc" >> "$log_file"
    else
        echo "$desc 失败"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: $desc" >> "$log_file"
        exit 1
    fi
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
        
        # 取第一个可用的网络接口
        NETWORK_INTERFACE=$(echo "$interfaces" | awk '{print $1}')
        echo "自动检测到网络接口: $NETWORK_INTERFACE"
    fi
    
    # 导出网络接口变量，使其在调用脚本中可用
    export NETWORK_INTERFACE
}

# 检查root权限
check_root() {
    if [ "$(id -u)" != "0" ]; then
        if check_chinese_support; then
            echo "错误: 请以root权限执行此脚本"
        else
            echo "Error: Please run this script as root"
        fi
        exit 1
    fi
}
