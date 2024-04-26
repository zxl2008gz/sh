#!/bin/bash

# 函数：退出
break_end() {
    echo -e "\033[0;32m操作完成\033[0m"
    echo "按任意键继续..."
    read -n 1 -s -r -p ""
    echo
    clear
}

install() {
    if [ $# -eq 0 ]; then
        echo "未提供软件包参数!"
        return 1
    fi

    for package in "$@"; do
        if ! command -v "$package" &>/dev/null; then
            if command -v dnf &>/dev/null; then
                echo "使用DNF安装 $package..."
                dnf -y update && dnf install -y "$package"
            elif command -v yum &>/dev/null; then
                echo "使用YUM安装 $package..."
                yum -y update && yum -y install "$package"
            elif command -v apt &>/dev/null; then
                echo "使用APT安装 $package..."
                apt update -y && apt install -y "$package"
            elif command -v apk &>/dev/null; then
                echo "使用APK安装 $package..."
                apk update && apk add "$package"
            else
                echo "未知的包管理器!"
                return 1
            fi
        else
            echo "$package 已经安装."
        fi
    done

    return 0
}

# 定义卸载软件包函数
remove() {
    if [ $# -eq 0 ]; then
        echo "未提供软件包参数!"
        return 1
    fi

    for package in "$@"; do
        if command -v "$package" &>/dev/null; then
            if command -v dnf &>/dev/null; then
                echo "使用DNF卸载 $package..."
                dnf remove -y "$package"
            elif command -v yum &>/dev/null; then
                echo "使用YUM卸载 $package..."
                yum remove -y "$package"
            elif command -v apt &>/dev/null; then
                echo "使用APT卸载 $package..."
                apt remove --purge -y "$package"
            elif command -v apk &>/dev/null; then
                echo "使用APK卸载 $package..."
                apk del "$package"
            else
                echo "未知的包管理器!"
                return 1
            fi
        else
            echo "$package 没有安装."
        fi
    done

    return 0
}

# 函数: 获取IP地址
get_ip_address() {
    local ipv4_address ipv6_address

    # 尝试获取 IPv4 地址
    ipv4_address=$(curl -s ipv4.ip.sb 2>/dev/null || echo "Unknown")
    if [ "$ipv4_address" = "Unknown" ]; then
        ipv4_address=""
    fi
    # 尝试获取 IPv6 地址
    ipv6_address=$(curl -s --max-time 1 ipv6.ip.sb 2>/dev/null || echo "Unknown")
    if [ "$ipv6_address" = "Unknown" ]; then
        ipv6_address=""
    fi    
    # 输出 IPv4 和 IPv6 地址
    echo "$ipv4_address $ipv6_address"
}

# 使用 /proc/stat 计算 CPU 使用率，以增加跨平台兼容性
get_cpu_usage() {
    # 读取 CPU 数据的第一行
    local cpu_line1=$(cat /proc/stat | grep '^cpu ' | awk '{print $2" "$3" "$4" "$5" "$6" "$7" "$8}')
    local user1=$(echo $cpu_line1 | awk '{print $1}')
    local nice1=$(echo $cpu_line1 | awk '{print $2}')
    local system1=$(echo $cpu_line1 | awk '{print $3}')
    local idle1=$(echo $cpu_line1 | awk '{print $4}')

    sleep 1

    # 再次读取 CPU 数据的第一行，以计算差异
    local cpu_line2=$(cat /proc/stat | grep '^cpu ' | awk '{print $2" "$3" "$4" "$5" "$6" "$7" "$8}')
    local user2=$(echo $cpu_line2 | awk '{print $1}')
    local nice2=$(echo $cpu_line2 | awk '{print $2}')
    local system2=$(echo $cpu_line2 | awk '{print $3}')
    local idle2=$(echo $cpu_line2 | awk '{print $4}')

    # 计算总的和空闲的 CPU 时间差
    local total1=$((user1 + nice1 + system1 + idle1))
    local total2=$((user2 + nice2 + system2 + idle2))
    local total_delta=$((total2 - total1))
    local idle_delta=$((idle2 - idle1))

    # 计算 CPU 使用率
    local usage=$((100 * (total_delta - idle_delta) / total_delta))

    echo "$usage"
}

# 获取虚拟内存
get_swap_info() {
    # 获取虚拟内存信息
    local swap_total=$(free -m 2>/dev/null | awk '/^Swap/ {print $2}' || echo "0")
    local swap_used=$(free -m 2>/dev/null | awk '/^Swap/ {print $3}' || echo "0")
    local swap_info

    if [ "$swap_total" -gt 0 ]; then
        swap_percentage=$((100 * swap_used / swap_total))
        swap_info="${swap_used}MB/${swap_total}MB ($swap_percentage%)"
    else
        swap_info="0MB/0MB (0%)"
    fi
    echo "$swap_used $swap_total $swap_percentage $swap_info"
}

# 函数: 显示系统信息
system_info_query() {
    clear

    # 获取IP地址
    read ipv4_address ipv6_address < <(get_ip_address)

    # 获取CPU信息
    local cpu_model=$(awk -F': ' '/^model name/ {print $2;exit}' /proc/cpuinfo 2>/dev/null || echo "Unknown")
    local cpu_cores=$(nproc 2>/dev/null || awk '/^cpu cores/ {print $4}' /proc/cpuinfo 2>/dev/null || echo "Unknown")
    # 调用函数并显示 CPU 使用率
    local cpu_usage=$(get_cpu_usage)

    # 获取内存信息
    local mem_info=$(free -b | awk 'NR==2{printf "%.2fMB/%.2f MB (%.2f%%)", $3/1024/1024, $2/1024/1024, $3*100/$2}')

    # 调用函数并读取结果
    read swap_used swap_total swap_percentage swap_info < <(get_swap_info)
    # 获取磁盘信息
    local disk_info=$(df -h 2>/dev/null | awk '$NF=="/"{printf "%s/%s (%s)", $3, $2, $5}' || echo "Unknown")

    # 获取网络传输信息
    local output=$(awk 'BEGIN { rx_total = 0; tx_total = 0 }
        NR > 2 { rx_total += $2; tx_total += $10 }
        END {
            rx_units = "Bytes";
            tx_units = "Bytes";
            if (rx_total > 1024) { rx_total /= 1024; rx_units = "KB"; }
            if (rx_total > 1024) { rx_total /= 1024; rx_units = "MB"; }
            if (rx_total > 1024) { rx_total /= 1024; rx_units = "GB"; }

            if (tx_total > 1024) { tx_total /= 1024; tx_units = "KB"; }
            if (tx_total > 1024) { tx_total /= 1024; tx_units = "MB"; }
            if (tx_total > 1024) { tx_total /= 1024; tx_units = "GB"; }

            printf("总接收: %.2f %s\n总发送: %.2f %s\n", rx_total, rx_units, tx_total, tx_units);
        }' /proc/net/dev)

    # 获取其他系统信息
    local country=$(curl -s ipinfo.io/country 2>/dev/null || echo "Unknown")
    local city=$(curl -s ipinfo.io/city 2>/dev/null || echo "Unknown")
    local isp_info=$(curl -s ipinfo.io/org 2>/dev/null || echo "Unknown")
    local cpu_arch=$(uname -m 2>/dev/null || echo "Unknown")
    local hostname=$(hostname 2>/dev/null || echo "Unknown")
    local kernel_version=$(uname -r 2>/dev/null || echo "Unknown")
    local congestion_algorithm=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "Unknown")
    local queue_algorithm=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "Unknown")
    local network_options="网络拥塞算法: $congestion_algorithm $queue_algorithm"
    local os_info=$(awk -F= '/^PRETTY_NAME=/ {print $2}' /etc/os-release 2>/dev/null | tr -d '"' || echo "Unknown")
    local current_time=$(date "+%Y-%m-%d %H:%M" 2>/dev/null || echo "Unknown")
    local runtime=$(awk '{run_days=int($1/86400); run_hours=int(($1%86400)/3600); run_minutes=int(($1%3600)/60); printf "%dd %dh %dm", run_days, run_hours, run_minutes}' /proc/uptime 2>/dev/null || echo "Unknown")

    # 输出信息
    cat <<EOF
系统信息查询
------------------------
主机名: $hostname
运营商: $isp_info
------------------------
系统版本: $os_info
Linux版本: $kernel_version
------------------------
CPU架构: $cpu_arch
CPU型号: $cpu_model
CPU核心数: $cpu_cores
------------------------
CPU占用: $cpu_usage%
物理内存: $mem_info
虚拟内存: $swap_info
硬盘占用: $disk_info
------------------------
$output
------------------------
$network_options
------------------------
公网IPv4地址: $ipv4_address
公网IPv6地址: $ipv6_address
------------------------
地理位置: $country $city
系统时间: $current_time
------------------------
系统运行时长: $runtime
EOF
}

# 函数：更新系统
update_service_info() {
    echo "开始更新系统..."
    # Update system on Debian-based systems
    if [ -f "/etc/debian_version" ]; then
        apt update -y && DEBIAN_FRONTEND=noninteractive apt full-upgrade -y
        echo "Debian-based system updated."
    fi

    # Update system on Red Hat-based systems using YUM or DNF
    if [ -f "/etc/redhat-release" ]; then
        if command -v dnf >/dev/null; then
            dnf -y update
            echo "Red Hat-based system updated using DNF."
        elif command -v yum >/dev/null; then
            yum -y update
            echo "Red Hat-based system updated using YUM."
        fi
    fi

    # Update system on Alpine Linux
    if [ -f "/etc/alpine-release" ]; then
        apk update && apk upgrade
        echo "Alpine Linux system updated."
    fi
}

# 函数：清理 Debian 系统
clean_debian() {
    echo "开始清理 Debian 系统..."
    apt-get autoremove --purge -y
    apt-get clean -y
    apt-get autoclean -y
    dpkg -l | awk '/^rc/ {print $2}' | xargs apt-get purge -y
    journalctl --rotate && journalctl --vacuum-time=1s && journalctl --vacuum-size=50M
    echo "Debian 系统清理完成。"
}

# 函数：清理 Red Hat 系统（YUM 或 DNF）
clean_redhat() {
    echo "开始清理 Red Hat 系统..."
    if command -v dnf >/dev/null; then
        dnf autoremove -y
        dnf clean all
    elif command -v yum >/dev/null; then
        yum autoremove -y
        yum clean all
    fi
    journalctl --rotate && journalctl --vacuum-time=1s && journalctl --vacuum-size=50M
    echo "Red Hat 系统清理完成。"
}

# 函数：清理 Alpine 系统
clean_alpine() {
    echo "开始清理 Alpine 系统..."
    apk update
    apk upgrade
    apk cache clean
    find /var/log -type f -exec truncate -s 0 {} \;
    find /tmp /var/tmp -type f -exec rm -f {} +
    echo "Alpine 系统清理完成。"
}

# 清理系统垃圾
clean_service_info() {
    echo "开始清理系统垃圾..."
    if [ "$(id -u)" != "0" ]; then
        echo "错误：此脚本需要以root权限运行。"
        exit 1
    fi

    if [ -f "/etc/debian_version" ]; then
        clean_debian
    elif [ -f "/etc/redhat-release" ]; then
        clean_redhat
    elif [ -f "/etc/alpine-release" ]; then
        clean_alpine
    else
        echo "未能识别的系统类型或系统不支持。"
        exit 1
    fi
}

# 常用工具
common_tool_install() {
    while true; do
        clear
        echo "▶ 安装常用工具"
        echo "------------------------"
        echo "1. curl 下载工具"
        echo "2. wget 下载工具"
        echo "3. sudo 超级管理权限工具"
        echo "4. socat 通信连接工具 （申请域名证书必备）"
        echo "5. htop 系统监控工具"
        echo "6. iftop 网络流量监控工具"
        echo "7. unzip ZIP压缩解压工具"
        echo "8. tar GZ压缩解压工具"
        echo "9. tmux 多路后台运行工具"
        echo "10. ffmpeg 视频编码直播推流工具"
        echo "11. btop 现代化监控工具"
        echo "12. ranger 文件管理工具"
        echo "13. gdu 磁盘占用查看工具"
        echo "14. fzf 全局搜索工具"
        echo "------------------------"
        echo "31. 全部安装"
        echo "32. 全部卸载"
        echo "------------------------"
        echo "41. 安装指定工具"
        echo "42. 卸载指定工具"
        echo "------------------------"
        echo "0. 返回主菜单"
        echo "------------------------"
        read -p "请输入你的选择: " sub_choice

        case $sub_choice in
            1)
                clear
                install curl
                clear
                echo "工具已安装，使用方法如下："
                curl --help
                break_end
                ;;
            2)
                clear
                install wget
                clear
                echo "工具已安装，使用方法如下："
                wget --help
                break_end
                ;;
            3)
                clear
                install sudo
                clear
                echo "工具已安装，使用方法如下："
                sudo --help
                break_end
                ;;
            4)
                clear
                install socat
                clear
                echo "工具已安装，使用方法如下："
                socat -h
                break_end
                ;;
            5)
                clear
                install htop
                clear
                htop
                break_end
                ;;
            6)
                clear
                install iftop
                clear
                iftop
                break_end
                ;;
            7)
                clear
                install unzip
                clear
                echo "工具已安装，使用方法如下："
                unzip
                break_end
                ;;
            8)
                clear
                install tar
                clear
                echo "工具已安装，使用方法如下："
                tar --help
                break_end
                ;;
            9)
                clear
                install tmux
                clear
                echo "工具已安装，使用方法如下："
                tmux --help
                break_end
                ;;
            10)
                clear
                install ffmpeg
                clear
                echo "工具已安装，使用方法如下："
                ffmpeg --help
                break_end
                ;;
            11)
                clear
                install btop
                clear
                btop
                break_end
                ;;                
            12)
                clear
                install ranger
                cd /
                clear
                ranger
                cd ~
                break_end
                ;;                
            13)
                clear
                install gdu
                cd /
                clear
                gdu
                cd ~
                break_end
                ;;                
            14)
                clear
                install fzf
                cd /
                clear
                fzf
                cd ~
                break_end
                ;;                
            31)
                clear
                install curl wget sudo socat htop iftop unzip tar tmux ffmpeg btop ranger gdu fzf
                break_end
                ;;
            32)
                clear
                remove htop iftop unzip tmux ffmpeg btop ranger gdu fzf
                break_end
                ;;
            41)
                clear
                read -p "请输入安装的工具名（wget curl sudo htop）: " installname
                install $installname
                break_end
                ;;
            42)
                clear
                read -p "请输入卸载的工具名（htop ufw tmux）: " removename
                remove $removename
                break_end
                ;;
            0)
                break
                ;;

            *)
                echo "无效的输入!"
                ;;
        esac
    done

}

# 主逻辑
case "$1" in
        query)
            system_info_query
            ;;
        update)
            update_service_info
            ;;
        clean)
            clean_service_info
            ;;
        commontool)
            common_tool_install
            ;;
        *)
            echo "Usage: $0 {update|state|uninstall|manage}"
            exit 1
    esac
