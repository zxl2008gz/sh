#!/bin/bash

# 判断是否已经存在 alias
if ! grep -q "alias k='./solin.sh'" ~/.bashrc; then
    # 如果不存在，则添加 alias
    echo "alias k='./solin.sh'" >> ~/.bashrc
    # 注意: 在脚本中 source .bashrc 可能不会有预期效果
    # 用户需要手动执行 `source ~/.bashrc` 或重新打开终端
else
    # 清除屏幕
    clear
fi

# 函数: 回到主菜单
solin() {
            cd ~
            ./solin.sh
            exit
}

# 函数: 获取IPv4地址
ipv4_address() {
    ipv4=$(curl -s ipv4.ip.sb)
}

# 函数: 获取IPv6地址
ipv6_address() {
    ipv6=$(curl -s --max-time 2 ipv6.ip.sb)
}

# 函数: 显示系统信息
show_system_info() {
    # 获取IP地址
    ipv4_address
    ipv6_address

    # 获取CPU信息
    if [ "$(uname -m)" == "x86_64" ]; then
        cpu_info=$(grep 'model name' /proc/cpuinfo | uniq | sed -e 's/model name[[:space:]]*: //')
    else
        cpu_info=$(lscpu | grep 'Model name' | sed -e 's/Model name[[:space:]]*: //')
    fi

    # 获取CPU使用率
    cpu_usage=$(top -bn1 | grep 'Cpu(s)' | awk '{print $2 + $4}')
    cpu_usage_percent=$(printf "%.2f%%" "$cpu_usage")

    # 获取CPU核心数
    cpu_cores=$(nproc)

    # 获取内存信息
    mem_info=$(free -m | awk 'NR==2{printf "%.2f/%.2f MB (%.2f%%)", $3/1024, $2/1024, $3*100/$2}')

    # 获取磁盘使用情况
    disk_info=$(df -h | awk '$NF=="/"{printf "%d/%dGB (%s)", $3,$2,$5}')

    # 获取ISP信息
    isp_info=$(curl -s ipinfo.io/org)

    # 获取CPU架构
    cpu_arch=$(uname -m)

    # 获取主机名
    hostname=$(hostname)

    # 获取内核版本
    kernel_version=$(uname -r)

    # 获取网络拥堵算法和队列算法
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

    # 获取网络接收和发送数据量
    network_io=$(awk 'BEGIN { rx_total = 0; tx_total = 0 }
        NR > 2 { rx_total += $2; tx_total += $10 }
        END {
            rx_units = "Bytes"; tx_units = "Bytes";
            if (rx_total > 1024) { rx_total /= 1024; rx_units = "KB"; }
            if (rx_total > 1024) { rx_total /= 1024; rx_units = "MB"; }
            if (rx_total > 1024) { rx_total /= 1024; rx_units = "GB"; }

            if (tx_total > 1024) { tx_total /= 1024; tx_units = "KB"; }
            if (tx_total > 1024) { tx_total /= 1024; tx_units = "MB"; }
            if (tx_total > 1024) { tx_total /= 1024; tx_units = "GB"; }

            printf("总接收: %.2f %s\n总发送: %.2f %s\n", rx_total, rx_units, tx_total, tx_units);
        }' /proc/net/dev)

    # 获取系统时间
    current_time=$(date "+%Y-%m-%d %H:%M:%S")

    # 获取交换空间使用情况
    swap_used=$(free -m | awk 'NR==3{print $3}')
    swap_total=$(free -m | awk 'NR==3{print $2}')
    swap_percentage=0
    if [ "$swap_total" -ne 0 ]; then
        swap_percentage=$((swap_used * 100 / swap_total))
    fi
    swap_info="${swap_used}MB/${swap_total}MB (${swap_percentage}%)"

    # 获取系统运行时长
    runtime=$(awk -F. '{run_days=int($1 / 86400); run_hours=int(($1 % 86400) / 3600); run_minutes=int(($1 % 3600) / 60); if (run_days > 0) printf("%d days ", run_days); if (run_hours > 0) printf("%d hours ", run_hours); printf("%d minutes\n", run_minutes)}' /proc/uptime)

    # 打印所有信息
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
    echo "$network_io"
    echo "------------------------"
    echo "网络拥堵算法: $congestion_algorithm $queue_algorithm"
    echo "------------------------"
    echo "公网IPv4地址: $ipv4"
    echo "公网IPv6地址: $ipv6"
    echo "------------------------"
    echo "系统时间: $current_time"
    echo "------------------------"
    echo "系统运行时长: $runtime"
    echo
    echo -e "\033[0;32m系统信息查询操作完成\033[0m"
}

# 函数：更新系统
update_service() {
    echo "开始更新系统..."

    # Debian-based systems
    if [ -f "/etc/debian_version" ]; then        
        echo "检测到基于Debian的系统。"
        apt-get update -y && apt-get upgrade -y
    fi

    # Red Hat-based systems
    if [ -f "/etc/redhat-release" ]; then
        echo "检测到基于Red Hat的系统。"
        yum -y update
    fi

    echo -e "\033[0;32m更新操作完成\033[0m"
}

# 清理Debian系统
clean_debian() {
	apt autoremove --purge -y
	apt clean -y
	apt autoclean -y
	apt remove --purge $(dpkg -l | awk '/^rc/ {print $2}') -y
	journalctl --rotate
	journalctl --vacuum-time=1s
	journalctl --vacuum-size=50M
	apt remove --purge $(dpkg -l | awk '/^ii linux-(image|headers)-[^ ]+/{print $2}' | grep -v $(uname -r | sed 's/-.*//') | xargs) -y
}

# 清理Red Hat-based systems系统
clean_redhat() {
	yum autoremove -y
	yum clean all
	journalctl --rotate
	journalctl --vacuum-time=1s
	journalctl --vacuum-size=50M
	yum remove $(rpm -q kernel | grep -v $(uname -r)) -y
}

# 清理系统垃圾
clean_service(){
    echo "开始清理系统垃圾..."

    # Debian-based systems
    if [ -f "/etc/debian_version" ]; then        
        echo "检测到基于Debian的系统。"
        clean_debian
    fi

    # Red Hat-based systems
    if [ -f "/etc/redhat-release" ]; then
        echo "检测到基于Red Hat的系统。"
        clean_redhat
    fi

   echo -e "\033[0;32m清理操作完成\033[0m"
}

# 在主循环之前定义一个变量
menu_exit=false

# 主循环，用于显示菜单并处理用户输入
while true; do
    clear  # 清除屏幕

    # 显示菜单
    echo -e "\033[96m _   _ "
    echo "|_  | |  |    | |\ | "
    echo " _| |_|  |___ | | \| "
    echo "                                "
    echo -e "\033[96m solin一键脚本工具 v1.0.0 （支持Ubuntu/Debian/CentOS系统）\033[0m"
    echo -e "\033[96m-输入\033[93mk\033[96m可快速启动此脚本-\033[0m"
    echo "------------------------"
    echo "1. 系统信息查询"
    echo "2. 系统更新"
    echo "3. 系统清理"
    echo "4. Docker管理 ▶ "
    echo -e "\033[33m5. LDNMP建站 ▶ \033[0m"
    echo "6. 系统工具 ▶ "
    echo "------------------------"
    echo "00. 脚本更新"
    echo "------------------------"
    echo "0. 退出脚本"
    echo "------------------------"

    # 读取用户输入
    read -p "请输入你的选择: " choice
    case $choice in
        1)
            clear
            show_system_info
            # 等待用户按键以返回菜单
            read -p "按任意键返回菜单..."			
            ;;
        2)
            clear
            update_service
            echo "请按任意键继续..."
            read -n 1 -s -r		
            ;;
        3)
            clear
            clean_service
            echo "请按任意键继续..."
            read -n 1 -s -r		
            ;;
        4)
            while true; do
				menu_exit=false  # 确保每次进入子菜单时，menu_exit 为 false
                clear
                echo "▶ Docker管理器"
                echo "------------------------"
                echo "1. 安装更新Docker环境"
                echo "------------------------"				
                echo "2. 查看Dcoker全局状态"
                echo "------------------------"
                echo "3. Dcoker容器管理 ▶"
                echo "4. Dcoker镜像管理 ▶"
                echo "5. Dcoker网络管理 ▶"
                echo "6. Dcoker卷管理 ▶"
                echo "------------------------"				
                echo "7. 清理无用的docker容器和镜像网络数据卷"	
                echo "------------------------"	
                echo "8. 卸载Dcoker环境"	
                echo "------------------------"		
                echo "0. 返回主菜单"
                echo "------------------------"
                read -p "请输入你的选择: " sub_choice

                case $sub_choice in
                    1)
                        # Docker安装更新逻辑
                        ;;
                    2)
                        # 查看Docker全局状态逻辑
                        ;;
                    3)
                        # Dcoker容器管理
                        ;;
                    4)
                        # Dcoker镜像管理
                        ;;
                    5)
                        # Dcoker网络管理
                        ;;
                    6)
                        # Dcoker卷管理
                        ;;	
                    7)
                        # 清理无用的docker容器和镜像网络数据卷
                        ;;
                    8)
                        # 卸载Dcoker环境
                        ;;						
                    0)
                        menu_exit=true  # 设置变量为true，表示需要退出内部循环
                        ;;
                    *)
                        echo "无效的选项，请重新输入！"
                        ;;
                esac
					# 检查是否需要退出内部循环
					if [ "$menu_exit" = true ]; then
						break
					fi
            done
            ;;
        5)
            while true; do
				menu_exit=false  # 确保每次进入子菜单时，menu_exit 为 false
                clear
                echo -e "\033[33m5. LDNMP建站 ▶ \033[0m"
                echo "------------------------"
                echo "1. 安装LDNMP环境"
                echo "------------------------"				
                echo "2. 安装WordPress"
                echo "------------------------"
                echo "3. 安装可道云桌面"
                echo "4. 安装独角数发卡网"
                echo "5. 安装LobeChat聊天网站"
                echo "6. 安装GeminiPro聊天网站"
                echo "7. 安装Bitwarden密码管理平台"
                echo "8. 安装epusdt加密usdt接码"				
                echo "------------------------"				
                echo "21. 仅安装nginx"	
                echo "22. 站点重定向"
				echo "23. 站点反向代理"
                echo -e "24. 自定义静态站点 \033[36mBeta\033[0m"				
                echo "------------------------"	
                echo "31. 站点数据管理"	
                echo "32. 备份全站数据"		
                echo "33. 定时远程备份"					
                echo "34. 还原全站数据"				
                echo "------------------------"
                echo "35. 站点防御程序"		
                echo "------------------------"
                echo "36. 优化LDNMP环境"					
                echo "37. 更新LDNMP环境"					
                echo "38. 卸载LDNMP环境"					
                echo "------------------------"				
                echo "0. 返回主菜单"
                echo "------------------------"
                read -p "请输入你的选择: " sub_choice

                case $sub_choice in
					1)
                        # 安装LDNMP环境
                        ;;
                    2)
                        # 安装WordPress
                        ;;
                    3)
                        # 安装可道云桌面
                        ;;
                    4)
                        # 安装独角数发卡网
                        ;;
                    5)
                        # 安装LobeChat聊天网站
                        ;;
                    6)
                        # 安装GeminiPro聊天网站
                        ;;	
                    7)
                        # 安装Bitwarden密码管理平台
                        ;;
                    8)
                        # 安装epusdt加密usdt接码
                        ;;		
                    21)
                        # 仅安装nginx
                        ;;		
                    22)
                        # 站点重定向
                        ;;		
                    23)
                        # 站点反向代理
                        ;;		
                    24)
                        # 自定义静态站点
                        ;;		
                    31)
                        # 站点数据管理
                        ;;		
                    32)
                        # 备份全站数据
                        ;;		
                    33)
                        # 定时远程备份
                        ;;		
                    34)
                        # 还原全站数据
                        ;;		
                    35)
                        # 站点防御程序
                        ;;		
                    36)
                        # 优化LDNMP环境
                        ;;		
                    37)
                        # 更新LDNMP环境
                        ;;		
                    38)
                        # 卸载LDNMP环境
                        ;;			
                    0)
                        menu_exit=true  # 设置变量为true，表示需要退出内部循环
                        ;;
                    *)
                        echo "无效的选项，请重新输入！"
                        ;;
                esac
					# 检查是否需要退出内部循环
					if [ "$menu_exit" = true ]; then
						break
					fi
            done
            ;;
        6)
            # 系统工具逻辑
            ;;
        00)
            # 脚本更新逻辑
            ;;
        0)
            # 退出脚本
			clear
            break
            ;;
        *)
            echo "无效的选项，请重新输入！"
            ;;
    esac
done
