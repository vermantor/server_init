#!/bin/bash

# OpenCloudOS 9 服务器自动初始化脚本

set -e

# 检测是否支持中文显示
check_chinese_support() {
    if locale -a | grep -q 'zh_CN.UTF-8' || rpm -q glibc-langpack-zh &> /dev/null; then
        return 0  # 支持中文
    else
        return 1  # 不支持中文
    fi
}

# 首先检查是否以root权限执行
if [ "$(id -u)" != "0" ]; then
    if check_chinese_support; then
        echo "错误: 请以root权限执行此脚本"
    else
        echo "Error: Please run this script as root"
    fi
    exit 1
fi

# 检查并安装中文语言支持
echo "检查中文语言支持..."
if [ "$(grep -c 'LANG=zh_CN.UTF-8' /etc/locale.conf)" -eq 0 ]; then
    # 安装中文语言包（OpenCloudOS 9使用不同的包名）
    if ! rpm -q glibc-langpack-zh &> /dev/null; then
        echo "安装中文语言包..."
        dnf install -y glibc-langpack-zh
    fi
    # 设置系统语言环境
    echo "设置中文语言环境..."
    echo "LANG=zh_CN.UTF-8" > /etc/locale.conf
    echo "LC_ALL=zh_CN.UTF-8" >> /etc/locale.conf
    # 立即生效
    export LANG=zh_CN.UTF-8
    export LC_ALL=zh_CN.UTF-8
    echo "中文语言支持配置完成"
else
    # 确保环境变量生效
    export LANG=zh_CN.UTF-8
    export LC_ALL=zh_CN.UTF-8
    echo "中文语言支持已配置，跳过"
fi

# 现在可以显示中文信息
echo "=== OpenCloudOS 9 服务器自动初始化脚本 ==="
echo "中文语言支持已就绪"

# 检查并安装git
echo "检查git安装情况..."
if ! command -v git &> /dev/null; then
    echo "未安装git，正在安装..."
    dnf install -y git
    if [ $? -eq 0 ]; then
        echo "git安装成功"
    else
        echo "git安装失败"
        exit 1
    fi
else
    echo "git已安装"
fi


# 检查.env文件是否存在
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        echo "未找到.env文件，正在从.env.example创建..."
        cp .env.example .env
        echo "请编辑.env文件设置您的配置，然后重新运行脚本"
        exit 1
    else
        echo "错误: 未找到.env或.env.example文件"
        exit 1
    fi
fi

# 加载.env文件
echo "加载配置文件..."
source .env

# 自动检测网络接口
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

# 定义日志文件
LOG_FILE="init.log"
touch $LOG_FILE
echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始执行初始化脚本" >> $LOG_FILE

# 函数: 执行命令并记录日志
exec_cmd() {
    local cmd="$1"
    local desc="$2"
    
    echo "$desc..."
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 执行: $desc" >> $LOG_FILE
    
    if eval "$cmd"; then
        echo "$desc 成功"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: $desc" >> $LOG_FILE
    else
        echo "$desc 失败"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: $desc" >> $LOG_FILE
        exit 1
    fi
}

# 1. 修改主机名
if [ ! -z "$HOSTNAME" ]; then
    # 检查主机名是否已设置
    current_hostname=$(hostname)
    if [ "$current_hostname" != "$HOSTNAME" ]; then
        exec_cmd "hostnamectl set-hostname $HOSTNAME" "修改主机名"
        exec_cmd "echo '$HOSTNAME' > /etc/hostname" "更新/etc/hostname文件"
    else
        echo "主机名已设置为 $HOSTNAME，跳过"
    fi
fi

# 2. 配置静态网络
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
    exec_cmd "cp -f /etc/sysconfig/network-scripts/ifcfg-$NETWORK_INTERFACE /etc/sysconfig/network-scripts/ifcfg-$NETWORK_INTERFACE.bak" "备份网络配置"
    
    # 生成新的网络配置
    cat > /etc/sysconfig/network-scripts/ifcfg-$NETWORK_INTERFACE << EOF
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
    
    exec_cmd "systemctl restart NetworkManager" "重启网络服务"
fi

# 3. 修改SSH端口
if [ ! -z "$SSH_PORT" ]; then
    # 检查SSH端口是否已设置
    current_port=$(grep -oP '^Port \K[0-9]+' /etc/ssh/sshd_config 2>/dev/null)
    if [ "$current_port" = "$SSH_PORT" ]; then
        echo "SSH端口已设置为 $SSH_PORT，跳过"
    else
        # 备份原有SSH配置
        exec_cmd "cp -f /etc/ssh/sshd_config /etc/ssh/sshd_config.bak" "备份SSH配置"
        
        # 修改SSH端口
        exec_cmd "sed -i 's/^#Port 22/Port $SSH_PORT/' /etc/ssh/sshd_config" "修改SSH端口"
        exec_cmd "sed -i 's/^Port 22/Port $SSH_PORT/' /etc/ssh/sshd_config" "确保SSH端口正确设置"
        
        # 配置防火墙
        exec_cmd "firewall-cmd --permanent --add-port=$SSH_PORT/tcp" "添加防火墙规则"
        exec_cmd "firewall-cmd --reload" "重新加载防火墙配置"
        
        exec_cmd "systemctl restart sshd" "重启SSH服务"
    fi
fi

# 4. 生成密钥对
if [ ! -z "$SSH_USER" ]; then
    USER_HOME=$(eval echo ~$SSH_USER)
    SSH_DIR="$USER_HOME/.ssh"
    
    # 检查.ssh目录是否存在
    if [ ! -d "$SSH_DIR" ]; then
        exec_cmd "mkdir -p $SSH_DIR" "创建.ssh目录"
        exec_cmd "chown $SSH_USER:$SSH_USER $SSH_DIR" "设置.ssh目录权限"
        exec_cmd "chmod 700 $SSH_DIR" "设置.ssh目录权限"
    fi
    
    # 生成密钥对
    if [ ! -f "$SSH_DIR/id_rsa" ]; then
        exec_cmd "su - $SSH_USER -c 'ssh-keygen -t rsa -b 2048 -N "" -f $SSH_DIR/id_rsa'" "生成SSH密钥对"
    else
        echo "SSH密钥对已存在，跳过"
    fi
    
    # 确保authorized_keys文件存在
    if [ ! -f "$SSH_DIR/authorized_keys" ]; then
        exec_cmd "touch $SSH_DIR/authorized_keys" "创建authorized_keys文件"
        exec_cmd "chown $SSH_USER:$SSH_USER $SSH_DIR/authorized_keys" "设置authorized_keys权限"
        exec_cmd "chmod 600 $SSH_DIR/authorized_keys" "设置authorized_keys权限"
    fi
    
    # 检查公钥是否已添加到authorized_keys
    if ! grep -q "$(cat $SSH_DIR/id_rsa.pub 2>/dev/null)" "$SSH_DIR/authorized_keys" 2>/dev/null; then
        exec_cmd "su - $SSH_USER -c 'cat $SSH_DIR/id_rsa.pub >> $SSH_DIR/authorized_keys'" "添加公钥到authorized_keys"
    else
        echo "公钥已添加到authorized_keys，跳过"
    fi
fi

# 5. 用户安全配置
if [ ! -z "$SSH_USER" ]; then
    sshd_config_changed=false
    
    # 检查并禁用root登录
    current_root_login=$(grep -oP '^PermitRootLogin \K\w+' /etc/ssh/sshd_config 2>/dev/null)
    if [ "$current_root_login" != "no" ]; then
        exec_cmd "sed -i 's/^#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config" "禁用root登录"
        exec_cmd "sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config" "确保root登录已禁用"
        sshd_config_changed=true
    else
        echo "root登录已禁用，跳过"
    fi
    
    # 检查并配置密码验证
    current_pw_auth=$(grep -oP '^PasswordAuthentication \K\w+' /etc/ssh/sshd_config 2>/dev/null)
    if [ "$current_pw_auth" != "$PASSWORD_AUTHENTICATION" ]; then
        if [ "$PASSWORD_AUTHENTICATION" = "yes" ]; then
            exec_cmd "sed -i 's/^#PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config" "启用密码验证"
            exec_cmd "sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config" "确保密码验证已启用"
        else
            exec_cmd "sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config" "禁用密码验证"
            exec_cmd "sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config" "确保密码验证已禁用"
        fi
        sshd_config_changed=true
    else
        echo "密码验证已配置为 $PASSWORD_AUTHENTICATION，跳过"
    fi
    
    # 重启SSH服务（如果配置有更改）
    if [ "$sshd_config_changed" = true ]; then
        exec_cmd "systemctl restart sshd" "重启SSH服务"
    fi
fi

# 额外安全配置
if [ "$ENABLE_FIREWALL" = "yes" ]; then
    # 检查防火墙服务状态
    if ! systemctl is-enabled firewalld &> /dev/null; then
        exec_cmd "systemctl enable firewalld" "启用防火墙服务"
    else
        echo "防火墙服务已启用，跳过"
    fi
    
    if ! systemctl is-active firewalld &> /dev/null; then
        exec_cmd "systemctl start firewalld" "启动防火墙服务"
    else
        echo "防火墙服务已运行，跳过"
    fi
fi

if [ "$INSTALL_FAIL2BAN" = "yes" ]; then
    # 检查Fail2ban是否已安装
    if ! rpm -q fail2ban &> /dev/null; then
        exec_cmd "dnf install -y fail2ban" "安装Fail2ban"
    else
        echo "Fail2ban已安装，跳过"
    fi
    
    if ! systemctl is-enabled fail2ban &> /dev/null; then
        exec_cmd "systemctl enable fail2ban" "启用Fail2ban服务"
    else
        echo "Fail2ban服务已启用，跳过"
    fi
    
    if ! systemctl is-active fail2ban &> /dev/null; then
        exec_cmd "systemctl start fail2ban" "启动Fail2ban服务"
    else
        echo "Fail2ban服务已运行，跳过"
    fi
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - 初始化脚本执行完成" >> $LOG_FILE
echo "=== 初始化完成 ==="
echo "请检查 $LOG_FILE 查看详细执行日志"
