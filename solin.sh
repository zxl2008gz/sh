#!/bin/bash

# 判断是否已经存在 alias
if ! grep -q "alias k='./solin.sh'" ~/.bashrc; then
    # 如果不存在，则添加 alias
    echo "alias k='./solin.sh'" >> ~/.bashrc
    # 重新加载.bashrc文件以应用更改
    source ~/.bashrc
else
    # 清除屏幕
    clear
fi

# 函数: 获取IPv4
ipv4_address() {
	ipv4_address=$(curl -s ipv4.ip.sb)

}

# 函数: 获取IPv6
ipv6_address() {
	ipv6_address=$(curl -s --max-time 2 ipv6.ip.sb)

}

# 函数: 获取IPv4和IPv6地址
fetch_ip_addresses() {
      ipv4_address
      ipv6_address

}

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
    echo -e "\033[33m4. LDNMP建站 ▶ \033[0m"
    echo "5. 系统工具 ▶ "
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
		
		# 获取IP地址
		fetch_ip_addresses
	
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
					
            # 系统信息查询逻辑
            ;;
        2)
            # 系统更新逻辑
            ;;
        3)
            # 系统清理逻辑
            ;;
        4)
            # 系统清理逻辑
            ;;
        # ... 其他选项的逻辑 ...
        0)
            # 退出脚本
            break
            ;;
        *)
            echo "无效的选项，请重新输入！"
            ;;
    esac
done
