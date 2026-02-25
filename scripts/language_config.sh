#!/bin/bash

# 语言配置模块

# 检查并安装中文语言支持
configure_language() {
    local log_file="$1"
    
    # 首先检查系统是否支持中文
    if locale -a | grep -q 'zh_CN.UTF-8' || rpm -q glibc-langpack-zh &> /dev/null; then
        # 系统支持中文，使用中文提示
        echo "检查中文语言支持..."
        
        if [ "$(grep -c 'LANG=zh_CN.UTF-8' /etc/locale.conf)" -eq 0 ]; then
            # 安装中文语言包（OpenCloudOS 9使用不同的包名）
            if ! rpm -q glibc-langpack-zh &> /dev/null; then
                echo "安装中文语言包..."
                dnf install -y glibc-langpack-zh
                if [ $? -eq 0 ]; then
                    echo "中文语言包安装成功"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 安装中文语言包" >> "$log_file"
                else
                    echo "中文语言包安装失败"
                    echo "$(date '+%Y-%m-%d %H:%M:%S') - 失败: 安装中文语言包" >> "$log_file"
                    exit 1
                fi
            fi
            
            # 设置系统语言环境
            echo "设置中文语言环境..."
            echo "LANG=zh_CN.UTF-8" > /etc/locale.conf
            echo "LC_ALL=zh_CN.UTF-8" >> /etc/locale.conf
            
            # 立即生效
            export LANG=zh_CN.UTF-8
            export LC_ALL=zh_CN.UTF-8
            
            echo "中文语言支持配置完成"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 成功: 配置中文语言环境" >> "$log_file"
        else
            # 确保环境变量生效
            export LANG=zh_CN.UTF-8
            export LC_ALL=zh_CN.UTF-8
            echo "中文语言支持已配置，跳过"
        fi
        
        # 现在可以显示中文信息
        echo "=== OpenCloudOS 9 服务器自动初始化脚本 ==="
        echo "中文语言支持已就绪"
    else
        # 系统不支持中文，使用英文提示
        echo "Checking Chinese language support..."
        
        # 安装中文语言包
        echo "Installing Chinese language pack..."
        dnf install -y glibc-langpack-zh
        if [ $? -eq 0 ]; then
            echo "Chinese language pack installed successfully"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Success: Install Chinese language pack" >> "$log_file"
            
            # 设置系统语言环境
            echo "Setting Chinese language environment..."
            echo "LANG=zh_CN.UTF-8" > /etc/locale.conf
            echo "LC_ALL=zh_CN.UTF-8" >> /etc/locale.conf
            
            # 立即生效
            export LANG=zh_CN.UTF-8
            export LC_ALL=zh_CN.UTF-8
            
            echo "Chinese language support configured successfully"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Success: Configure Chinese language environment" >> "$log_file"
            
            # 现在可以显示中文信息
            echo "=== OpenCloudOS 9 服务器自动初始化脚本 ==="
            echo "中文语言支持已就绪"
        else
            echo "Failed to install Chinese language pack"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Failed: Install Chinese language pack" >> "$log_file"
            exit 1
        fi
    fi
}
