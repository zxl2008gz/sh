#!/bin/bash

# 判断是否已经存在 alias
if ! grep -q "alias k='./solin.sh'" ~/.bashrc; then
    # 如果不存在，则添加 alias
    echo "alias k='./solin.sh'" >> ~/.bashrc
    source ~/.bashrc
else
    clear
fi


ipv4_address() {
  ipv4_address=$(curl -s ipv4.ip.sb)
}


# 这个install函数是一个通用的软件包安装器，它自动检测Linux系统上的包管理器（apt或yum），并尝试安装用户指定的一个或多个软件包。
# 如果没有提供任何软件包名，或者系统上没有已知的包管理器，它将返回错误。这个函数可以在多种基于Debian和基于RedHat的Linux发行版上工作。
install() {
    if [ $# -eq 0 ]; then
        echo "未提供软件包参数!"
        return 1
    fi

    for package in "$@"; do
        if ! command -v "$package" &>/dev/null; then
            if command -v apt &>/dev/null; then
                apt update -y && apt install -y "$package"
            elif command -v yum &>/dev/null; then
                yum -y update && yum -y install "$package"
            else
                echo "未知的包管理器!"
                return 1
            fi
        fi
    done

    return 0
}

# install_dependency 函数是一个便利的封装，用于安装一组常用工具。通过调用已定义的 install 函数，它简化了多个软件包的安装过程。
install_dependency() {
      clear
      install wget socat unzip tar
}

# remove函数是一个通用的软件包卸载器，它自动检测Linux系统上的包管理器（apt或yum），并尝试移除用户指定的一个或多个软件包。
# 如果没有提供任何软件包名，或者系统上没有已知的包管理器，它将返回错误。这个函数可以在多种基于Debian和基于RedHat的Linux发行版上工作。
# 它尝试彻底清理软件包和相关配置文件（使用apt purge而不是仅仅apt remove），以确保系统的整洁。
remove() {
    if [ $# -eq 0 ]; then
        echo "未提供软件包参数!"
        return 1
    fi

    for package in "$@"; do
        if command -v apt &>/dev/null; then
            apt purge -y "$package"
        elif command -v yum &>/dev/null; then
            yum remove -y "$package"
        else
            echo "未知的包管理器!"
            return 1
        fi
    done

    return 0
}

# break_end 函数是一个用户友好的结束提示，用于在脚本或一系列命令执行完毕后通知用户并等待其响应以继续。
# 它通过打印彩色的“操作完成”消息、等待用户按键并清除屏幕来实现这一点。这种函数在交互式脚本中非常有用，可以提供更好的用户体验。
break_end() {
      echo -e "\033[0;32m操作完成\033[0m"
      echo "按任意键继续..."
      read -n 1 -s -r -p ""
      echo ""
      clear
}

# 这段代码的目的是执行solin.sh脚本，并且在执行完后退出当前的shell。
solin() {
            cd ~
            ./solin.sh
            exit
}


# 定义要检测的端口
check_port() {    
    PORT=443

    # 检查端口占用情况
    result=$(ss -tulpn | grep ":$PORT")

    # 判断结果并输出相应信息
    if [ -n "$result" ]; then
        is_nginx_container=$(docker ps --format '{{.Names}}' | grep 'nginx')

        # 判断是否是Nginx容器占用端口
        if [ -n "$is_nginx_container" ]; then
            echo ""
        else
            clear
            echo -e "\e[1;31m端口 $PORT 已被占用，无法安装环境，卸载以下程序后重试！\e[0m"
            echo "$result"
            break_end
            kejilion

        fi
    else
        echo ""
    fi
}

# 定义安装 Docker 的函数
install_docker() {
    if ! command -v docker &>/dev/null; then
        curl -fsSL https://get.docker.com | sh && ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin
        systemctl start docker
        systemctl enable docker
    else
        echo "Docker 已经安装"
    fi
}



while true; do
clear

echo -e "\033[96m_  _ ____  _ _ _    _ ____ _  _ "
echo "|_  |___  | | |    | |  | |\ | "
echo "  | _ |___ _| | |___ | |__| | \| "
echo "                                "
echo -e "\033[96m科技lion一键脚本工具 v2.1.5 （支持Ubuntu/Debian/CentOS系统）\033[0m"
echo -e "\033[96m-输入\033[93mk\033[96m可快速启动此脚本-\033[0m"
echo "------------------------"
echo "1. 系统信息查询"
echo "2. 系统更新"
echo "3. 系统清理"
echo "4. 常用工具 ▶"
echo "5. BBR管理 ▶"
echo "6. Docker管理 ▶ "
echo "7. WARP管理 ▶ 解锁ChatGPT Netflix"
echo "8. 测试脚本合集 ▶ "
echo "9. 甲骨文云脚本合集 ▶ "
echo -e "\033[33m10. LDNMP建站 ▶ \033[0m"
echo "11. 面板工具 ▶ "
echo "12. 我的工作区 ▶ "
echo "13. 系统工具 ▶ "
echo "------------------------"
echo "00. 脚本更新"
echo "------------------------"
echo "0. 退出脚本"
echo "------------------------"
read -p "请输入你的选择: " choice

case $choice in
  1)
    clear
    # 函数: 获取IPv4和IPv6地址
    fetch_ip_addresses() {
      ipv4_address
      ipv6_address=$(curl -s --max-time 2 ipv6.ip.sb)

    }

    # 获取IP地址
    fetch_ip_addresses

    if [ "$(uname -m)" == "x86_64" ]; then
      cpu_info=$(cat /proc/cpuinfo | grep 'model name' | uniq | sed -e 's/model name[[:space:]]*: //')
    else
      cpu_info=$(lscpu | grep 'Model name' | sed -e 's/Model name[[:space:]]*: //')
    fi

    cpu_usage=$(top -bn1 | grep 'Cpu(s)' | awk '{print $2 + $4}')
    cpu_usage_percent=$(printf "%.2f" "$cpu_usage")%

    cpu_cores=$(nproc)

    mem_info=$(free -b | awk 'NR==2{printf "%.2f/%.2f MB (%.2f%%)", $3/1024/1024, $2/1024/1024, $3*100/$2}')

    disk_info=$(df -h | awk '$NF=="/"{printf "%d/%dGB (%s)", $3,$2,$5}')

    country=$(curl -s ipinfo.io/country)
    city=$(curl -s ipinfo.io/city)

    isp_info=$(curl -s ipinfo.io/org)

    cpu_arch=$(uname -m)

    hostname=$(hostname)

    kernel_version=$(uname -r)

    congestion_algorithm=$(sysctl -n net.ipv4.tcp_congestion_control)
    queue_algorithm=$(sysctl -n net.core.default_qdisc)

    # 尝试使用 lsb_release 获取系统信息
    os_info=$(lsb_release -ds 2>/dev/null)

    # 如果 lsb_release 命令失败，则尝试其他方法
    if [ -z "$os_info" ]; then
      # 检查常见的发行文件
      if [ -f "/etc/os-release" ]; then
        os_info=$(source /etc/os-release && echo "$PRETTY_NAME")
      elif [ -f "/etc/debian_version" ]; then
        os_info="Debian $(cat /etc/debian_version)"
      elif [ -f "/etc/redhat-release" ]; then
        os_info=$(cat /etc/redhat-release)
      else
        os_info="Unknown"
      fi
    fi

    clear
    output=$(awk 'BEGIN { rx_total = 0; tx_total = 0 }
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


    current_time=$(date "+%Y-%m-%d %I:%M %p")


    swap_used=$(free -m | awk 'NR==3{print $3}')
    swap_total=$(free -m | awk 'NR==3{print $2}')

    if [ "$swap_total" -eq 0 ]; then
        swap_percentage=0
    else
        swap_percentage=$((swap_used * 100 / swap_total))
    fi

    swap_info="${swap_used}MB/${swap_total}MB (${swap_percentage}%)"

    runtime=$(cat /proc/uptime | awk -F. '{run_days=int($1 / 86400);run_hours=int(($1 % 86400) / 3600);run_minutes=int(($1 % 3600) / 60); if (run_days > 0) printf("%d天 ", run_days); if (run_hours > 0) printf("%d时 ", run_hours); printf("%d分\n", run_minutes)}')

    echo ""
    echo "系统信息查询"
    echo "------------------------"
    echo "主机名: $hostname"
    echo "运营商: $isp_info"
    echo "------------------------"
    echo "系统版本: $os_info"
    echo "Linux版本: $kernel_version"
    echo "------------------------"
    echo "CPU架构: $cpu_arch"
    echo "CPU型号: $cpu_info"
    echo "CPU核心数: $cpu_cores"
    echo "------------------------"
    echo "CPU占用: $cpu_usage_percent"
    echo "物理内存: $mem_info"
    echo "虚拟内存: $swap_info"
    echo "硬盘占用: $disk_info"
    echo "------------------------"
    echo "$output"
    echo "------------------------"
    echo "网络拥堵算法: $congestion_algorithm $queue_algorithm"
    echo "------------------------"
    echo "公网IPv4地址: $ipv4_address"
    echo "公网IPv6地址: $ipv6_address"
    echo "------------------------"
    echo "地理位置: $country $city"
    echo "系统时间: $current_time"
    echo "------------------------"
    echo "系统运行时长: $runtime"
    echo

    ;;
