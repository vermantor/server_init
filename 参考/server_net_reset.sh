#!/bin/bash

# =====================================================
# 网络连接自动修复脚本
# 适用于 CentOS/RHEL 9
# 作者: System Admin
# 版本: 2.0
# =====================================================

# =====================================================
# 可配置参数 - 在这里修改你的网络设置
# =====================================================

# 网络连接方式: "dhcp" 或 "static"
# dhcp: 自动获取IP
# static: 手动设置静态IP
NETWORK_MODE="dhcp"

# 静态IP配置（仅在 NETWORK_MODE="static" 时生效）
STATIC_IP="192.168.1.100/24"        # IP地址/子网掩码
STATIC_GATEWAY="192.168.1.1"         # 网关地址
STATIC_DNS="8.8.8.8 114.114.114.114" # DNS服务器（空格分隔）

# 网卡设置
AUTOCONNECT="yes"                     # 是否开机自动连接 (yes/no)
CONNECTION_PREFIX="eth"               # 连接名前缀

# 高级设置
DEBUG_MODE="no"                        # 调试模式 (yes/no)
PING_TEST_HOSTS="8.8.8.8 baidu.com"    # 网络测试主机

# =====================================================
# 脚本开始 - 以下内容无需修改
# =====================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    if [ "$DEBUG_MODE" = "yes" ]; then
        echo -e "[DEBUG] $1"
    fi
}

# 检查root权限
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        log_error "请以root权限运行此脚本"
        echo "使用方法: sudo $0"
        exit 1
    fi
}

# 检查必要命令
check_requirements() {
    local missing_tools=()
    
    if ! command -v nmcli &> /dev/null; then
        missing_tools+=("NetworkManager")
    fi
    
    if ! command -v ip &> /dev/null; then
        missing_tools+=("iproute2")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "缺少必要工具: ${missing_tools[*]}"
        log_info "请安装缺失的工具后重试"
        exit 1
    fi
}

# 显示配置信息
show_config() {
    echo "====================================================="
    echo "              网络连接修复脚本 v2.0"
    echo "====================================================="
    log_info "当前配置:"
    log_info "  网络模式: $NETWORK_MODE"
    if [ "$NETWORK_MODE" = "static" ]; then
        log_info "  IP地址: $STATIC_IP"
        log_info "  网关: $STATIC_GATEWAY"
        log_info "  DNS: $STATIC_DNS"
    fi
    log_info "  自动连接: $AUTOCONNECT"
    log_info "  连接前缀: $CONNECTION_PREFIX"
    echo "====================================================="
    echo ""
}

# 获取物理网卡列表
get_network_interfaces() {
    local interfaces=""
    
    log_debug "正在检测网络设备..."
    
    # 使用nmcli获取
    if command -v nmcli &> /dev/null; then
        interfaces=$(nmcli -t -f DEVICE,TYPE dev status 2>/dev/null | grep ":ethernet" | cut -d: -f1)
        log_debug "nmcli找到的网卡: $interfaces"
    fi
    
    # 如果nmcli没找到，使用ip命令
    if [ -z "$interfaces" ]; then
        interfaces=$(ip -o link show | grep -v "lo:" | grep "state" | awk -F': ' '{print $2}' | grep -E "^e|^en" | head -5)
        log_debug "ip命令找到的网卡: $interfaces"
    fi
    
    # 去重
    interfaces=$(echo "$interfaces" | sort -u | tr '\n' ' ')
    
    if [ -z "$interfaces" ]; then
        log_error "没有找到可用的以太网卡！"
        log_info "尝试搜索所有网络设备..."
        interfaces=$(ip -o link show | grep -v "lo:" | awk -F': ' '{print $2}' | grep -v "^dummy\|^virbr\|^vnet\|^docker" | head -5 | tr '\n' ' ')
    fi
    
    echo "$interfaces"
}

# 启用网卡
enable_interface() {
    local iface=$1
    local state=$(ip link show $iface | grep "state" | awk '{print $9}')
    
    log_debug "网卡 $iface 当前状态: $state"
    
    if [ "$state" = "DOWN" ]; then
        log_info "正在启用网卡 $iface..."
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
    
    log_debug "清理网卡 $iface 的旧连接..."
    
    # 通过接口名查找并删除
    nmcli -t -f NAME,DEVICE con show 2>/dev/null | grep ":$iface$" | cut -d: -f1 | while read conn; do
        log_info "删除旧连接(接口匹配): $conn"
        nmcli con del "$conn" 2>/dev/null
    done
    
    # 通过MAC地址查找并删除
    if [ ! -z "$mac" ]; then
        nmcli -t -f NAME,802-3-ethernet.mac-address con show 2>/dev/null | grep -i "$mac" | cut -d: -f1 | while read conn; do
            log_info "删除旧连接(MAC匹配): $conn"
            nmcli con del "$conn" 2>/dev/null
        done
    fi
}

# 创建新连接
create_connection() {
    local iface=$1
    local mac=$2
    local conn_name="${CONNECTION_PREFIX}-${iface}"
    
    # 检查连接名是否已存在
    local counter=1
    while nmcli con show "$conn_name" &>/dev/null; do
        conn_name="${CONNECTION_PREFIX}-${iface}-${counter}"
        ((counter++))
    done
    
    log_info "创建新连接: $conn_name"
    
    # 创建基本连接
    nmcli con add con-name "$conn_name" ifname "$iface" type ethernet
    
    # 设置MAC地址（提高稳定性）
    if [ ! -z "$mac" ]; then
        nmcli con mod "$conn_name" 802-3-ethernet.mac-address "$mac"
    fi
    
    # 设置自动连接
    nmcli con mod "$conn_name" connection.autoconnect "$AUTOCONNECT"
    
    # 根据模式配置IP
    if [ "$NETWORK_MODE" = "static" ]; then
        log_info "配置静态IP: $STATIC_IP"
        nmcli con mod "$conn_name" ipv4.addresses "$STATIC_IP"
        nmcli con mod "$conn_name" ipv4.gateway "$STATIC_GATEWAY"
        nmcli con mod "$conn_name" ipv4.dns "$STATIC_DNS"
        nmcli con mod "$conn_name" ipv4.method manual
    else
        log_info "配置DHCP自动获取IP"
        nmcli con mod "$conn_name" ipv4.method auto
    fi
    
    echo "$conn_name"
}

# 测试网络连接
test_network() {
    log_info "测试网络连通性..."
    
    local success=0
    local total=0
    
    for host in $PING_TEST_HOSTS; do
        total=$((total + 1))
        if ping -c 2 -W 3 "$host" &>/dev/null; then
            log_success "可以ping通: $host"
            success=$((success + 1))
        else
            log_warning "无法ping通: $host"
        fi
    done
    
    if [ $success -eq 0 ] && [ $total -gt 0 ]; then
        log_error "所有网络测试都失败！"
        return 1
    elif [ $success -lt $total ]; then
        log_warning "部分网络测试失败"
        return 2
    else
        log_success "所有网络测试通过"
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
    log_info "活跃连接:"
    nmcli con show --active 2>/dev/null | tail -n +2 | while read line; do
        echo "  $line"
    done
    
    echo ""
    log_info "IP地址信息:"
    ip -4 addr show | grep -v "127.0.0.1" | grep inet | while read line; do
        echo "  $line"
    done
    
    echo ""
    log_info "路由信息:"
    ip route show | grep default | while read line; do
        echo "  $line"
    done
    
    echo ""
    log_info "DNS配置:"
    cat /etc/resolv.conf | grep nameserver | while read line; do
        echo "  $line"
    done
    
    echo "====================================================="
}

# 主函数
main() {
    check_root
    check_requirements
    show_config
    
    # 获取网卡列表
    INTERFACES=$(get_network_interfaces)
    
    if [ -z "$INTERFACES" ]; then
        log_error "没有找到可用的网络接口！"
        log_info "请检查:"
        log_info "  1. 网卡是否已插好"
        log_info "  2. 驱动是否正常加载 (lspci | grep Ethernet)"
        log_info "  3. 虚拟机是否启用了网卡"
        exit 1
    fi
    
    log_info "找到以下网络接口: $INTERFACES"
    
    local success_count=0
    local total_count=0
    
    # 处理每个网卡
    for IFACE in $INTERFACES; do
        total_count=$((total_count + 1))
        echo ""
        echo "-----------------------------------"
        log_info "处理网卡: ${YELLOW}$IFACE${NC}"
        
        # 获取MAC地址
        MAC=$(get_mac_address "$IFACE")
        log_info "MAC地址: $MAC"
        
        # 启用网卡
        enable_interface "$IFACE"
        
        # 清理旧连接
        cleanup_old_connections "$IFACE" "$MAC"
        
        # 创建新连接
        CONN_NAME=$(create_connection "$IFACE" "$MAC")
        
        # 激活连接
        log_info "激活连接 $CONN_NAME..."
        if nmcli con up "$CONN_NAME" &>/dev/null; then
            log_success "网卡 $IFACE 连接成功！"
            success_count=$((success_count + 1))
        else
            log_error "网卡 $IFACE 连接失败！"
            
            # 尝试备用方法
            log_warning "尝试备用连接方法..."
            nmcli dev connect "$IFACE" &>/dev/null
            
            if [ $? -eq 0 ]; then
                log_success "备用方法连接成功！"
                success_count=$((success_count + 1))
            else
                log_error "备用方法也失败了"
            fi
        fi
        
        sleep 1
    done
    
    echo ""
    echo "====================================================="
    log_info "处理完成: $success_count/$total_count 个网卡连接成功"
    
    # 显示网络状态
    show_network_status
    
    # 测试网络
    echo ""
    test_network
    local test_result=$?
    
    echo ""
    if [ $test_result -eq 0 ]; then
        log_success "网络配置成功！"
    elif [ $test_result -eq 2 ]; then
        log_warning "网络部分可用，可能需要手动检查DNS配置"
    else
        log_error "网络配置可能有问题，请手动检查"
    fi
    
    echo "====================================================="
}

# 执行主函数
main#!/bin/bash

# =====================================================
# 网络连接自动修复脚本
# 适用于 CentOS/RHEL 9
# 作者: System Admin
# 版本: 2.0
# =====================================================

# =====================================================
# 可配置参数 - 在这里修改你的网络设置
# =====================================================

# 网络连接方式: "dhcp" 或 "static"
# dhcp: 自动获取IP
# static: 手动设置静态IP
NETWORK_MODE="dhcp"

# 静态IP配置（仅在 NETWORK_MODE="static" 时生效）
STATIC_IP="192.168.1.100/24"        # IP地址/子网掩码
STATIC_GATEWAY="192.168.1.1"         # 网关地址
STATIC_DNS="8.8.8.8 114.114.114.114" # DNS服务器（空格分隔）

# 网卡设置
AUTOCONNECT="yes"                     # 是否开机自动连接 (yes/no)
CONNECTION_PREFIX="eth"               # 连接名前缀

# 高级设置
DEBUG_MODE="no"                        # 调试模式 (yes/no)
PING_TEST_HOSTS="8.8.8.8 baidu.com"    # 网络测试主机

# =====================================================
# 脚本开始 - 以下内容无需修改
# =====================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    if [ "$DEBUG_MODE" = "yes" ]; then
        echo -e "[DEBUG] $1"
    fi
}

# 检查root权限
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        log_error "请以root权限运行此脚本"
        echo "使用方法: sudo $0"
        exit 1
    fi
}

# 检查必要命令
check_requirements() {
    local missing_tools=()
    
    if ! command -v nmcli &> /dev/null; then
        missing_tools+=("NetworkManager")
    fi
    
    if ! command -v ip &> /dev/null; then
        missing_tools+=("iproute2")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "缺少必要工具: ${missing_tools[*]}"
        log_info "请安装缺失的工具后重试"
        exit 1
    fi
}

# 显示配置信息
show_config() {
    echo "====================================================="
    echo "              网络连接修复脚本 v2.0"
    echo "====================================================="
    log_info "当前配置:"
    log_info "  网络模式: $NETWORK_MODE"
    if [ "$NETWORK_MODE" = "static" ]; then
        log_info "  IP地址: $STATIC_IP"
        log_info "  网关: $STATIC_GATEWAY"
        log_info "  DNS: $STATIC_DNS"
    fi
    log_info "  自动连接: $AUTOCONNECT"
    log_info "  连接前缀: $CONNECTION_PREFIX"
    echo "====================================================="
    echo ""
}

# 获取物理网卡列表
get_network_interfaces() {
    local interfaces=""
    
    log_debug "正在检测网络设备..."
    
    # 使用nmcli获取
    if command -v nmcli &> /dev/null; then
        interfaces=$(nmcli -t -f DEVICE,TYPE dev status 2>/dev/null | grep ":ethernet" | cut -d: -f1)
        log_debug "nmcli找到的网卡: $interfaces"
    fi
    
    # 如果nmcli没找到，使用ip命令
    if [ -z "$interfaces" ]; then
        interfaces=$(ip -o link show | grep -v "lo:" | grep "state" | awk -F': ' '{print $2}' | grep -E "^e|^en" | head -5)
        log_debug "ip命令找到的网卡: $interfaces"
    fi
    
    # 去重
    interfaces=$(echo "$interfaces" | sort -u | tr '\n' ' ')
    
    if [ -z "$interfaces" ]; then
        log_error "没有找到可用的以太网卡！"
        log_info "尝试搜索所有网络设备..."
        interfaces=$(ip -o link show | grep -v "lo:" | awk -F': ' '{print $2}' | grep -v "^dummy\|^virbr\|^vnet\|^docker" | head -5 | tr '\n' ' ')
    fi
    
    echo "$interfaces"
}

# 启用网卡
enable_interface() {
    local iface=$1
    local state=$(ip link show $iface | grep "state" | awk '{print $9}')
    
    log_debug "网卡 $iface 当前状态: $state"
    
    if [ "$state" = "DOWN" ]; then
        log_info "正在启用网卡 $iface..."
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
    
    log_debug "清理网卡 $iface 的旧连接..."
    
    # 通过接口名查找并删除
    nmcli -t -f NAME,DEVICE con show 2>/dev/null | grep ":$iface$" | cut -d: -f1 | while read conn; do
        log_info "删除旧连接(接口匹配): $conn"
        nmcli con del "$conn" 2>/dev/null
    done
    
    # 通过MAC地址查找并删除
    if [ ! -z "$mac" ]; then
        nmcli -t -f NAME,802-3-ethernet.mac-address con show 2>/dev/null | grep -i "$mac" | cut -d: -f1 | while read conn; do
            log_info "删除旧连接(MAC匹配): $conn"
            nmcli con del "$conn" 2>/dev/null
        done
    fi
}

# 创建新连接
create_connection() {
    local iface=$1
    local mac=$2
    local conn_name="${CONNECTION_PREFIX}-${iface}"
    
    # 检查连接名是否已存在
    local counter=1
    while nmcli con show "$conn_name" &>/dev/null; do
        conn_name="${CONNECTION_PREFIX}-${iface}-${counter}"
        ((counter++))
    done
    
    log_info "创建新连接: $conn_name"
    
    # 创建基本连接
    nmcli con add con-name "$conn_name" ifname "$iface" type ethernet
    
    # 设置MAC地址（提高稳定性）
    if [ ! -z "$mac" ]; then
        nmcli con mod "$conn_name" 802-3-ethernet.mac-address "$mac"
    fi
    
    # 设置自动连接
    nmcli con mod "$conn_name" connection.autoconnect "$AUTOCONNECT"
    
    # 根据模式配置IP
    if [ "$NETWORK_MODE" = "static" ]; then
        log_info "配置静态IP: $STATIC_IP"
        nmcli con mod "$conn_name" ipv4.addresses "$STATIC_IP"
        nmcli con mod "$conn_name" ipv4.gateway "$STATIC_GATEWAY"
        nmcli con mod "$conn_name" ipv4.dns "$STATIC_DNS"
        nmcli con mod "$conn_name" ipv4.method manual
    else
        log_info "配置DHCP自动获取IP"
        nmcli con mod "$conn_name" ipv4.method auto
    fi
    
    echo "$conn_name"
}

# 测试网络连接
test_network() {
    log_info "测试网络连通性..."
    
    local success=0
    local total=0
    
    for host in $PING_TEST_HOSTS; do
        total=$((total + 1))
        if ping -c 2 -W 3 "$host" &>/dev/null; then
            log_success "可以ping通: $host"
            success=$((success + 1))
        else
            log_warning "无法ping通: $host"
        fi
    done
    
    if [ $success -eq 0 ] && [ $total -gt 0 ]; then
        log_error "所有网络测试都失败！"
        return 1
    elif [ $success -lt $total ]; then
        log_warning "部分网络测试失败"
        return 2
    else
        log_success "所有网络测试通过"
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
    log_info "活跃连接:"
    nmcli con show --active 2>/dev/null | tail -n +2 | while read line; do
        echo "  $line"
    done
    
    echo ""
    log_info "IP地址信息:"
    ip -4 addr show | grep -v "127.0.0.1" | grep inet | while read line; do
        echo "  $line"
    done
    
    echo ""
    log_info "路由信息:"
    ip route show | grep default | while read line; do
        echo "  $line"
    done
    
    echo ""
    log_info "DNS配置:"
    cat /etc/resolv.conf | grep nameserver | while read line; do
        echo "  $line"
    done
    
    echo "====================================================="
}

# 主函数
main() {
    check_root
    check_requirements
    show_config
    
    # 获取网卡列表
    INTERFACES=$(get_network_interfaces)
    
    if [ -z "$INTERFACES" ]; then
        log_error "没有找到可用的网络接口！"
        log_info "请检查:"
        log_info "  1. 网卡是否已插好"
        log_info "  2. 驱动是否正常加载 (lspci | grep Ethernet)"
        log_info "  3. 虚拟机是否启用了网卡"
        exit 1
    fi
    
    log_info "找到以下网络接口: $INTERFACES"
    
    local success_count=0
    local total_count=0
    
    # 处理每个网卡
    for IFACE in $INTERFACES; do
        total_count=$((total_count + 1))
        echo ""
        echo "-----------------------------------"
        log_info "处理网卡: ${YELLOW}$IFACE${NC}"
        
        # 获取MAC地址
        MAC=$(get_mac_address "$IFACE")
        log_info "MAC地址: $MAC"
        
        # 启用网卡
        enable_interface "$IFACE"
        
        # 清理旧连接
        cleanup_old_connections "$IFACE" "$MAC"
        
        # 创建新连接
        CONN_NAME=$(create_connection "$IFACE" "$MAC")
        
        # 激活连接
        log_info "激活连接 $CONN_NAME..."
        if nmcli con up "$CONN_NAME" &>/dev/null; then
            log_success "网卡 $IFACE 连接成功！"
            success_count=$((success_count + 1))
        else
            log_error "网卡 $IFACE 连接失败！"
            
            # 尝试备用方法
            log_warning "尝试备用连接方法..."
            nmcli dev connect "$IFACE" &>/dev/null
            
            if [ $? -eq 0 ]; then
                log_success "备用方法连接成功！"
                success_count=$((success_count + 1))
            else
                log_error "备用方法也失败了"
            fi
        fi
        
        sleep 1
    done
    
    echo ""
    echo "====================================================="
    log_info "处理完成: $success_count/$total_count 个网卡连接成功"
    
    # 显示网络状态
    show_network_status
    
    # 测试网络
    echo ""
    test_network
    local test_result=$?
    
    echo ""
    if [ $test_result -eq 0 ]; then
        log_success "网络配置成功！"
    elif [ $test_result -eq 2 ]; then
        log_warning "网络部分可用，可能需要手动检查DNS配置"
    else
        log_error "网络配置可能有问题，请手动检查"
    fi
    
    echo "====================================================="
}

# 执行主函数
main