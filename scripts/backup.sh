#!/bin/bash

# 备份和恢复模块

# 创建备份目录
BACKUP_DIR="backups"
mkdir -p "$BACKUP_DIR"

# 备份系统配置
backup_config() {
    local log_file="$1"
    local backup_name="$BACKUP_DIR/config_$(date '+%Y%m%d_%H%M%S')"
    
    echo "正在创建系统配置备份..."
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始: 创建系统配置备份" >> "$log_file"
    
    # 创建备份目录
    mkdir -p "$backup_name"
    
    # 备份网络配置
    echo "备份网络配置..."
    mkdir -p "$backup_name/network"
    nmcli con export enp1s0 > "$backup_name/network/enp1s0.nmconnection" 2>/dev/null
    cp -r /etc/sysconfig/network-scripts/ "$backup_name/network/" 2>/dev/null
    
    # 备份SSH配置
    echo "备份SSH配置..."
    mkdir -p "$backup_name/ssh"
    cp /etc/ssh/sshd_config "$backup_name/ssh/"
    
    # 备份防火墙配置
    echo "备份防火墙配置..."
    mkdir -p "$backup_name/firewall"
    firewall-cmd --list-all > "$backup_name/firewall/firewall.conf" 2>/dev/null
    
    # 备份用户配置
    echo "备份用户配置..."
    mkdir -p "$backup_name/users"
    cp /etc/passwd "$backup_name/users/"
    cp /etc/group "$backup_name/users/"
    cp /etc/shadow "$backup_name/users/" 2>/dev/null
    
    # 备份主机名配置
    echo "备份主机名配置..."
    mkdir -p "$backup_name/hostname"
    hostname > "$backup_name/hostname/hostname"
    cp /etc/hostname "$backup_name/hostname/"
    
    # 创建压缩包
    echo "创建备份压缩包..."
    tar -czf "$backup_name.tar.gz" "$backup_name"
    
    # 清理临时目录
    rm -rf "$backup_name"
    
    echo "系统配置备份成功: $backup_name.tar.gz"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 系统配置备份成功" >> "$log_file"
    
    return 0
}

# 恢复系统配置
restore_config() {
    local log_file="$1"
    local backup_file="$2"
    
    if [ ! -f "$backup_file" ]; then
        echo "错误: 备份文件不存在"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 错误: 备份文件不存在" >> "$log_file"
        return 1
    fi
    
    echo "正在恢复系统配置..."
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始: 恢复系统配置" >> "$log_file"
    
    # 创建临时目录
    local temp_dir="$BACKUP_DIR/temp_$(date '+%Y%m%d_%H%M%S')"
    mkdir -p "$temp_dir"
    
    # 解压备份文件
    echo "解压备份文件..."
    tar -xzf "$backup_file" -C "$temp_dir"
    
    # 恢复网络配置
    echo "恢复网络配置..."
    if [ -d "$temp_dir/*/network" ]; then
        cp -r "$temp_dir"/*/network/* /etc/sysconfig/network-scripts/ 2>/dev/null
        nmcli con reload 2>/dev/null
    fi
    
    # 恢复SSH配置
    echo "恢复SSH配置..."
    if [ -f "$temp_dir"/*/ssh/sshd_config ]; then
        cp "$temp_dir"/*/ssh/sshd_config /etc/ssh/
        systemctl restart sshd 2>/dev/null
    fi
    
    # 恢复防火墙配置
    echo "恢复防火墙配置..."
    if [ -f "$temp_dir"/*/firewall/firewall.conf ]; then
        # 简单恢复，实际生产环境可能需要更复杂的处理
        firewall-cmd --reload 2>/dev/null
    fi
    
    # 恢复主机名配置
    echo "恢复主机名配置..."
    if [ -f "$temp_dir"/*/hostname/hostname ]; then
        local hostname=$(cat "$temp_dir"/*/hostname/hostname)
        hostnamectl set-hostname "$hostname"
        cp "$temp_dir"/*/hostname/hostname /etc/
    fi
    
    # 清理临时目录
    rm -rf "$temp_dir"
    
    echo "系统配置恢复成功"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 系统配置恢复成功" >> "$log_file"
    
    return 0
}

# 列出可用的备份
list_backups() {
    echo "可用的备份文件:"
    ls -la "$BACKUP_DIR"/*.tar.gz 2>/dev/null || echo "无备份文件"
}