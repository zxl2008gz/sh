#!/bin/bash

huang='\033[33m'
bai='\033[0m'
lv='\033[0;32m'
lan='\033[0;34m'
hong='\033[31m'
lianglan='\033[96m'
hui='\e[37m'

# 函数：退出
break_end() {
    echo -e "${lv}操作完成${bai}"
    echo "按任意键继续..."
    read -n 1 -s -r -p ""
    echo
    clear
}

# 函数：询问用户确认
ask_confirmation() {
    local prompt="$1"
    local choice

    while true; do
        read -p "$prompt (Y/N): " choice
        case "$choice" in
            [Yy]) return 0 ;;
            [Nn]) return 1 ;;
            *) echo "无效的选择，请输入 Y 或 N。" ;;
        esac
    done
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

# 设置或移除BBR
configure_bbr() {
    local enable=$1  # 传入 'enable' 或 'disable'
    if [ "$enable" = "enable" ]; then
        cat > /etc/sysctl.conf << EOF
net.core.default_qdisc=fq_pie
net.ipv4.tcp_congestion_control=bbr
EOF
    elif [ "$enable" = "disable" ]; then
        sed -i '/net.core.default_qdisc=fq_pie/d' /etc/sysctl.conf
        sed -i '/net.ipv4.tcp_congestion_control=bbr/d' /etc/sysctl.conf
    fi
    sysctl -p
}

# BBR脚本
bbr_script() {
    clear
    if [ -f "/etc/alpine-release" ]; then
        while true; do
            clear
            local congestion_algorithm=$(sysctl -n net.ipv4.tcp_congestion_control)
            local queue_algorithm=$(sysctl -n net.core.default_qdisc)
            echo "当前TCP阻塞算法: $congestion_algorithm $queue_algorithm"

            echo ""
            echo "BBR管理"
            echo "------------------------"
            echo "1. 开启BBRv3              2. 关闭BBRv3（会重启）"
            echo "------------------------"
            echo "0. 返回上一级选单"
            echo "------------------------"
            read -p "请输入你的选择: " sub_choice

            case $sub_choice in
                1)
                    configure_bbr enable
                    ;;
                2)
                    configure_bbr disable
                    reboot
                    ;;
                0)
                    break
                    ;;
                *)
                    break
                    ;;
            esac
        done
    else
        install wget
        wget --no-check-certificate -O tcpx.sh https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcpx.sh
        chmod +x tcpx.sh
        ./tcpx.sh
    fi
}

# 设置虚拟内存
add_swap() {
    local new_swap_size="$1"  # 新的 swap 文件大小（以 MB 为单位）

    if [[ -z "$new_swap_size" || ! "$new_swap_size" =~ ^[0-9]+$ ]]; then
        echo "错误：请提供一个有效的数字作为 swap 大小（以 MB 为单位）。" 
        return 1
    fi

    echo "正在禁用并清理现有的 swap 分区..."
    local swap_partitions=$(grep -E '^/dev/' /proc/swaps | awk '{print $1}')
    for partition in $swap_partitions; do
        swapoff "$partition" && wipefs -a "$partition" && mkswap -f "$partition"
    done

    echo "正在处理 /swapfile..."
    swapoff /swapfile 2>/dev/null
    rm -f /swapfile

    echo "创建新的 swap 文件，大小为 ${new_swap_size}MB..."
    dd if=/dev/zero of=/swapfile bs=1M count=$new_swap_size status=progress
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile

    if [ -f /etc/alpine-release ]; then
        echo "为 Alpine Linux 配置 swap..."
        echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
        echo "nohup swapon /swapfile" >> /etc/local.d/swap.start
        chmod +x /etc/local.d/swap.start
        rc-update add local
    else
        echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
    fi

    echo "虚拟内存大小已调整为 ${new_swap_size}MB"
}

# 判断当前swap的大小
panduan_swap() {
    # 获取当前的 swap 总大小（以 MB 为单位）
    current_swap_size=$(free -m | awk '/Swap:/ {print $2}')
    # 判断当前的 swap 大小是否小于或等于 1024 MB
    if [[ "$current_swap_size" -le 1024 ]]; then
        echo "当前的 swap 小于或等于 1024 MB，需要增加 swap 空间。"
        add_swap 1024
    else
        echo "当前的 swap 已经超过 1024 MB，无需增加。"
    fi
}

# 测试脚本
test_script() {
    while true; do
        clear
        echo "▶ 测试脚本合集"
        echo ""
        echo "-----解锁状态检测--------"        
        echo "1. ChatGPT解锁状态检测"
        echo "2. Region流媒体解锁测试"
        echo "3. yeahwu流媒体解锁检测"
        echo "4. xykt_IP质量体检脚本"
        echo ""
        echo "------网络线路测速------------"
        echo "21. besttrace三网回程延迟路由测试"
        echo "22. mtr_trace三网回程线路测试"
        echo "23. Superspeed三网测速"
        echo "24. nxtrace快速回程测试脚本"
        echo "25. nxtrace指定IP回程测试脚本"
        echo "26. ludashi2020三网线路测试"
        echo ""
        echo "----硬件性能测试----------"
        echo "41. yabs性能测试"
        echo "42. icu/gb5 CPU性能测试脚本"
        echo ""
        echo "----综合性测试-----------"
        echo "61. bench性能测试"
        echo -e "62. spiritysdx融合怪测评 "
        echo "------------------------"
        echo "0. 返回主菜单"
        echo "------------------------"
        read -p "请输入你的选择: " sub_choice

        case $sub_choice in
            1)
                clear
                bash <(curl -Ls https://cdn.jsdelivr.net/gh/missuo/OpenAI-Checker/openai.sh)
                break_end
                ;;
            2)
                clear
                bash <(curl -L -s check.unlock.media)
                break_end
                ;;
            3)
                clear
                install wget
                wget -qO- https://github.com/yeahwu/check/raw/main/check.sh | bash
                break_end
                ;;
            4)
                clear
                bash <(curl -Ls IP.Check.Place)
                break_end
                ;;
            21)
                clear
                install wget
                wget -qO- git.io/besttrace | bash
                break_end
                ;;
            22)
                clear
                curl https://raw.githubusercontent.com/zhucaidan/mtr_trace/main/mtr_trace.sh | bash
                break_end
                ;;
            23)
                clear
                bash <(curl -Lso- https://git.io/superspeed_uxh)
                break_end
                ;;
            24)
                clear
                curl nxtrace.org/nt |bash
                nexttrace --fast-trace --tcp
                break_end
                ;;
            25)
                clear

                echo "可参考的IP列表"
                echo "------------------------"
                echo "北京电信: 219.141.136.12"
                echo "北京联通: 202.106.50.1"
                echo "北京移动: 221.179.155.161"
                echo "上海电信: 202.96.209.133"
                echo "上海联通: 210.22.97.1"
                echo "上海移动: 211.136.112.200"
                echo "广州电信: 58.60.188.222"
                echo "广州联通: 210.21.196.6"
                echo "广州移动: 120.196.165.24"
                echo "成都电信: 61.139.2.69"
                echo "成都联通: 119.6.6.6"
                echo "成都移动: 211.137.96.205"
                echo "湖南电信: 36.111.200.100"
                echo "湖南联通: 42.48.16.100"
                echo "湖南移动: 39.134.254.6"
                echo "------------------------"

                read -p "输入一个指定IP: " testip
                curl nxtrace.org/nt |bash
                nexttrace $testip
                break_end
                ;;
            26)
                clear
                curl https://raw.githubusercontent.com/ludashi2020/backtrace/main/install.sh -sSf | sh
                break_end
                ;;
            41)
                clear
                add_swap 1024
                curl -sL yabs.sh | bash -s -- -i -5
                break_end
                ;;
            42)
                clear
                panduan_swap
                bash <(curl -sL bash.icu/gb5)
                break_end
                ;;
            61)
                clear
                curl -Lso- bench.sh | bash
                break_end
                ;; 
            62)
                clear
                curl -L https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh -o ecs.sh && chmod +x ecs.sh && bash ecs.sh
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

# 设置root密码
set_rootpasswd() {

    echo "设置你的ROOT密码"
    passwd
    if [ $? -ne 0 ]; then
        echo "密码设置失败，请重试。"
        return 1
    fi
    # 修改 SSH 配置以允许 root 登录
    echo "正在修改 SSH 配置以允许 ROOT 登录..."
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
    service sshd restart
    if [ $? -ne 0 ]; then
        echo "SSH 服务重启失败，请手动重启服务。"
        return 1
    fi

    echo "ROOT登录设置完毕！"
    while true; do
        read -p "需要重启服务器吗？(Y/N): " choice
        case "$choice" in
            [Yy])
                echo "正在重启服务器..."
                reboot
                ;;
            [Nn])
                echo "已取消重启。"
                ;;
            0)
                solin
                ;;
            *)
                echo "无效的选择，请输入 Y 或 N。"
                ;;
        esac
    done
}

# DD系统1
dd_xitong_1() {    
    read -p "请输入你重装后的密码: " vpspasswd
    echo "任意键继续，重装后初始用户名: root  初始密码: $vpspasswd  初始端口: 22"
    read -n 1 -s -r -p ""
    install wget
    bash <(wget --no-check-certificate -qO- 'https://raw.githubusercontent.com/MoeClub/Note/master/InstallNET.sh') $xitong -v 64 -p $vpspasswd -port 22
}

# 检查Docker是否安装
check_docker_installed() {
    if ! command -v docker &>/dev/null; then
        echo "Docker 未安装。"
        return 1
    fi
}

# 定义安装更新 Docker 的函数
update_docker() {
    if [ -f "/etc/alpine-release" ]; then
        # 更新软件包索引
        apk update

        # 安装一个更完整的内核版本
        # apk add linux-lts

        # 安装 Docker
        apk add docker

        # 将 Docker 添加到默认运行级别并启动
        rc-update add docker default
        Limit_log
        service docker start || rc-service docker start

        # 安装 Docker Compose
        apk add docker-compose

    else
        # 其他 Linux 发行版，使用 Docker 的官方安装脚本
        curl -fsSL https://get.docker.com | sh

        # Docker Compose 需要单独安装，这里使用 Linux 的通用安装方法
        # 注意：这里需要检查 Docker Compose 的官方GitHub仓库以获得最新安装步骤
        LATEST_COMPOSE=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
        curl -L "https://github.com/docker/compose/releases/download/${LATEST_COMPOSE}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose

        # 为了兼容性，检查是否安装了 systemctl，如果是则启动并使能 Docker 服务
        if command -v systemctl &>/dev/null; then
            systemctl start docker
            systemctl enable docker
            Limit_log  
        fi
    fi

    sleep 2
}

# 甲骨文脚本
oracle_script() {
    while true; do
        clear
        echo "▶ 甲骨文云脚本合集"
        echo "------------------------"
        echo "1. 安装闲置机器活跃脚本"
        echo "2. 卸载闲置机器活跃脚本"
        echo "------------------------"
        echo "3. DD重装系统脚本"
        echo "4. R探长开机脚本"
        echo "------------------------"
        echo "5. 开启ROOT密码登录模式"
        echo "------------------------"
        echo "0. 返回主菜单"
        echo "------------------------"
        read -p "请输入你的选择: " sub_choice

        case $sub_choice in
            1)
                clear
                echo "活跃脚本: CPU占用10-20% 内存占用15% "
                if ask_confirmation "确定安装闲置机器活跃脚本吗？"; then
                    if check_docker_installed; then
                        echo "Docker is installed."
                    else
                        update_docker
                    fi
                    docker run -itd --name=lookbusy --restart=always \
                        -e TZ=Asia/Shanghai \
                        -e CPU_UTIL=10-20 \
                        -e CPU_CORE=1 \
                        -e MEM_UTIL=15 \
                        -e SPEEDTEST_INTERVAL=120 \
                        fogforest/lookbusy
                    echo "活跃脚本安装完成。"
                else
                    echo "安装已取消。"
                fi
                ;;
            2)
                clear
                if docker rm -f lookbusy && docker rmi fogforest/lookbusy; then
                    echo "闲置机器活跃脚本已卸载。"
                else
                    echo "卸载失败，请检查 Docker 是否运行。"
                fi
                ;;
            3)
                clear
                echo "请备份数据，将为你重装系统，预计花费15分钟。"
                read -p "确定继续吗？(Y/N): " choice

                case "$choice" in
                    [Yy])
                        while true; do
                            read -p "请选择要重装的系统:  1. Debian12 | 2. Ubuntu20.04 : " sys_choice

                            case "$sys_choice" in
                                1)
                                    xitong="-d 12"
                                    break  # 结束循环
                                    ;;
                                2)
                                    xitong="-u 20.04"
                                    break  # 结束循环
                                    ;;
                                *)
                                    echo "无效的选择，请重新输入。"
                                    ;;
                            esac
                        done
                        
                        dd_xitong_1
                        ;;
                    [Nn])
                        echo "已取消"
                        ;;
                    *)
                        echo "无效的选择，请输入 Y 或 N。"
                        ;;
                esac
                ;;

            4)
                clear
                echo "该功能处于开发阶段，敬请期待！"
                ;;
            5)
                clear
                set_rootpasswd
                ;;
            0)
                # 退出脚本
                break
                ;;
            *)
                echo "无效的选项，请重新输入！"
                ;;
        esac
        break_end
    done
}

# GCP DD系统1
gcp_xitong_1() {    
    read -p "请输入你重装后的密码: " vpspasswd
    read -p "请输入你需要重装的VPS的内网IP: " ip_addr
    # 简单验证IP地址格式
    if [[ $ip_addr =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        gateway="${ip_addr%.*}.1"
        echo "任意键继续，重装后初始用户名: root  初始密码: $vpspasswd  初始端口: 22"
        read -n 1 -s -r -p ""
        install wget
        bash <(wget --no-check-certificate -qO- 'https://raw.githubusercontent.com/MoeClub/Note/master/InstallNET.sh') --ip-addr $ip_addr --ip-gate $gateway --ip-mask 255.255.255.0 $xitong -v 64 -p $vpspasswd -port 22 
    else
        echo "输入的IP地址格式不正确。"
    fi
}

#谷歌云脚本
gcp_script() {
    while true; do
        clear
        echo "▶ 谷歌云脚本合集"
        echo "------------------------"
        echo "1. DD重装系统脚本"
        echo "------------------------"
        echo "0. 返回主菜单"
        echo "------------------------"
        read -p "请输入你的选择: " sub_choice

        case $sub_choice in
            1)
                clear
                echo "请备份数据，将为你重装系统，预计花费15分钟。"
                read -p "确定继续吗？(Y/N): " choice

                case "$choice" in
                    [Yy])
                        while true; do
                            read -p "请选择要重装的系统:  1. Debian12 | 2. Ubuntu20.04 : " sys_choice

                            case "$sys_choice" in
                                1)
                                    xitong="-d 12"
                                    break  # 结束循环
                                    ;;
                                2)
                                    xitong="-u 20.04"
                                    break  # 结束循环
                                    ;;
                                *)
                                    echo "无效的选择，请重新输入。"
                                    ;;
                            esac
                        done
                        
                        gcp_xitong_1
                        ;;
                    [Nn])
                        echo "已取消"
                        ;;
                    *)
                        echo "无效的选择，请输入 Y 或 N。"
                        ;;
                esac
                ;;
            0)
                # 退出脚本
                solin
                ;;
            *)
                echo "无效的选项，请重新输入！"
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
        bbr)
            bbr_script
            ;;
        test)
            test_script
            ;;
        oracle)
            oracle_script
            ;;
        gcp)
            gcp_script
            ;;
        *)
            echo "Usage: $0 {update|query|clean|commontool|bbr|test|oracle|gcp}"
            exit 1
    esac
