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

break_end() {
      echo -e "\033[0;32m操作完成\033[0m"
      echo "按任意键继续..."
      read -n 1 -s -r -p ""
      echo
      clear
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

 # 查看Docker全局状态逻辑
check_docker() {
	echo "Dcoker版本"
	docker --version
	docker-compose --version
	echo ""
	echo "Dcoker镜像列表"
	docker image ls
	echo ""
	echo "Dcoker容器列表"
	docker ps -a
	echo ""
	echo "Dcoker卷列表"
	docker volume ls
	echo ""
	echo "Dcoker网络列表"
	docker network ls
	echo ""
}

# 定义检测端口
check_port() {
    # 定义要检测的端口
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
            solin
        fi
    else
        echo ""
    fi
}

# 安装依赖
install_dependency() {
      clear
      install wget socat unzip tar iptables
}

install_certbot() {
    install certbot

    # 切换到一个一致的目录（例如，家目录）
    cd ~ || exit

    # 下载并使脚本可执行
    curl -O https://raw.githubusercontent.com/kejilion/sh/main/auto_cert_renewal.sh
    chmod +x auto_cert_renewal.sh

    # 安排每日午夜运行脚本
    echo "0 0 * * * cd ~ && ./auto_cert_renewal.sh" | crontab -
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
            ;;
        2)
            clear
            update_service
            ;;
        3)
            clear
            clean_service
            ;;
        4)
            while true; do
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
			clear
   			install_docker
	     		;;
                    2)
                        # 查看Docker全局状态逻辑
			clear
   			check_docker
                        ;;
                    3)
			# Dcoker容器管理
			while true; do
			  clear
			  echo "Docker容器列表"
			  docker ps -a
			  echo ""
			  echo "容器操作"
			  echo "------------------------"
			  echo "1. 创建新的容器"
			  echo "------------------------"
			  echo "2. 启动指定容器             6. 启动所有容器"
			  echo "3. 停止指定容器             7. 暂停所有容器"
			  echo "4. 删除指定容器             8. 删除所有容器"
			  echo "5. 重启指定容器             9. 重启所有容器"
			  echo "------------------------"
			  echo "11. 进入指定容器           12. 查看容器日志           13. 查看容器网络"
			  echo "------------------------"
			  echo "0. 返回上一级选单"
			  echo "------------------------"
			  read -p "请输入你的选择: " sub_choice
			
			  case $sub_choice in
			      1)
				  read -p "请输入创建命令: " dockername
				  $dockername
				  ;;
			
			      2)
				  read -p "请输入容器名: " dockername
				  docker start $dockername
				  ;;
			      3)
				  read -p "请输入容器名: " dockername
				  docker stop $dockername
				  ;;
			      4)
				  read -p "请输入容器名: " dockername
				  docker rm -f $dockername
				  ;;
			      5)
				  read -p "请输入容器名: " dockername
				  docker restart $dockername
				  ;;
			      6)
				  docker start $(docker ps -a -q)
				  ;;
			      7)
				  docker stop $(docker ps -q)
				  ;;
			      8)
				  read -p "确定删除所有容器吗？(Y/N): " choice
				  case "$choice" in
				    [Yy])
				      docker rm -f $(docker ps -a -q)
				      ;;
				    [Nn])
				      ;;
				    *)
				      echo "无效的选择，请输入 Y 或 N。"
				      ;;
				  esac
				  ;;
			      9)
				  docker restart $(docker ps -q)
				  ;;
			      11)
				  read -p "请输入容器名: " dockername
				  docker exec -it $dockername /bin/bash
				  break_end
				  ;;
			      12)
				  read -p "请输入容器名: " dockername
				  docker logs $dockername
				  break_end
				  ;;
			      13)
				  echo ""
				  container_ids=$(docker ps -q)
			
				  echo "------------------------------------------------------------"
				  printf "%-25s %-25s %-25s\n" "容器名称" "网络名称" "IP地址"
			
				  for container_id in $container_ids; do
				      container_info=$(docker inspect --format '{{ .Name }}{{ range $network, $config := .NetworkSettings.Networks }} {{ $network }} {{ $config.IPAddress }}{{ end }}' "$container_id")
			
				      container_name=$(echo "$container_info" | awk '{print $1}')
				      network_info=$(echo "$container_info" | cut -d' ' -f2-)
			
				      while IFS= read -r line; do
					  network_name=$(echo "$line" | awk '{print $1}')
					  ip_address=$(echo "$line" | awk '{print $2}')
			
					  printf "%-20s %-20s %-15s\n" "$container_name" "$network_name" "$ip_address"
				      done <<< "$network_info"
				  done
			
				  break_end
				  ;;
			
			      0)
				  break  # 跳出循环，退出菜单
				  ;;
			
			      *)
				  break  # 跳出循环，退出菜单
				  ;;
			  esac
			done
                        ;;
                    4)
                        # Dcoker镜像管理
			while true; do
			  clear
			  echo "Docker镜像列表"
			  docker image ls
			  echo ""
			  echo "镜像操作"
			  echo "------------------------"
			  echo "1. 获取指定镜像             3. 删除指定镜像"
			  echo "2. 更新指定镜像             4. 删除所有镜像"
			  echo "------------------------"
			  echo "0. 返回上一级选单"
			  echo "------------------------"
			  read -p "请输入你的选择: " sub_choice
			
			  case $sub_choice in
			      1)
				  read -p "请输入镜像名: " dockername
				  docker pull $dockername
				  ;;
			      2)
				  read -p "请输入镜像名: " dockername
				  docker pull $dockername
				  ;;
			      3)
				  read -p "请输入镜像名: " dockername
				  docker rmi -f $dockername
				  ;;
			      4)
				  read -p "确定删除所有镜像吗？(Y/N): " choice
				  case "$choice" in
				    [Yy])
				      docker rmi -f $(docker images -q)
				      ;;
				    [Nn])
			
				      ;;
				    *)
				      echo "无效的选择，请输入 Y 或 N。"
				      ;;
				  esac
				  ;;
			      0)
				  break  # 跳出循环，退出菜单
				  ;;
			
			      *)
				  break  # 跳出循环，退出菜单
				  ;;
			  esac
			done
                        ;;
                    5)
                        # Dcoker网络管理
			while true; do
			  clear
			  echo "Docker网络列表"
			  echo "------------------------------------------------------------"
			  docker network ls
			  echo ""
			
			  echo "------------------------------------------------------------"
			  container_ids=$(docker ps -q)
			  printf "%-25s %-25s %-25s\n" "容器名称" "网络名称" "IP地址"
			
			  for container_id in $container_ids; do
			      container_info=$(docker inspect --format '{{ .Name }}{{ range $network, $config := .NetworkSettings.Networks }} {{ $network }} {{ $config.IPAddress }}{{ end }}' "$container_id")
			
			      container_name=$(echo "$container_info" | awk '{print $1}')
			      network_info=$(echo "$container_info" | cut -d' ' -f2-)
			
			      while IFS= read -r line; do
				  network_name=$(echo "$line" | awk '{print $1}')
				  ip_address=$(echo "$line" | awk '{print $2}')
			
				  printf "%-20s %-20s %-15s\n" "$container_name" "$network_name" "$ip_address"
			      done <<< "$network_info"
			  done
			
			  echo ""
			  echo "网络操作"
			  echo "------------------------"
			  echo "1. 创建网络"
			  echo "2. 加入网络"
			  echo "3. 退出网络"
			  echo "4. 删除网络"
			  echo "------------------------"
			  echo "0. 返回上一级选单"
			  echo "------------------------"
			  read -p "请输入你的选择: " sub_choice
			
			  case $sub_choice in
			      1)
				  read -p "设置新网络名: " dockernetwork
				  docker network create $dockernetwork
				  ;;
			      2)
				  read -p "加入网络名: " dockernetwork
				  read -p "那些容器加入该网络: " dockername
				  docker network connect $dockernetwork $dockername
				  echo ""
				  ;;
			      3)
				  read -p "退出网络名: " dockernetwork
				  read -p "那些容器退出该网络: " dockername
				  docker network disconnect $dockernetwork $dockername
				  echo ""
				  ;;
			
			      4)
				  read -p "请输入要删除的网络名: " dockernetwork
				  docker network rm $dockernetwork
				  ;;
			      0)
				  break  # 跳出循环，退出菜单
				  ;;
			
			      *)
				  break  # 跳出循环，退出菜单
				  ;;
			  esac
			done
                        ;;
                    6)
                        # Dcoker卷管理
			while true; do
			  clear
			  echo "Docker卷列表"
			  docker volume ls
			  echo ""
			  echo "卷操作"
			  echo "------------------------"
			  echo "1. 创建新卷"
			  echo "2. 删除卷"
			  echo "------------------------"
			  echo "0. 返回上一级选单"
			  echo "------------------------"
			  read -p "请输入你的选择: " sub_choice
			
			  case $sub_choice in
			      1)
				  read -p "设置新卷名: " dockerjuan
				  docker volume create $dockerjuan
			
				  ;;
			      2)
				  read -p "输入删除卷名: " dockerjuan
				  docker volume rm $dockerjuan
			
				  ;;
			      0)
				  break  # 跳出循环，退出菜单
				  ;;
			
			      *)
				  break  # 跳出循环，退出菜单
				  ;;
			  esac
			done
                        ;;	
                    7)
                        # 清理无用的docker容器和镜像网络数据卷
			clear
			read -p "确定清理无用的镜像容器网络吗？(Y/N): " choice
			case "$choice" in
				[Yy])
					docker system prune -af --volumes
					;;
				[Nn])
					;;
				*)
					echo "无效的选择，请输入 Y 或 N。"
					;;
			esac
                        ;;
                    8)
                       # 卸载Docker环境
			clear
			read -p "确定卸载docker环境吗？(Y/N): " choice
			case "$choice" in
			    [Yy])
			        # 停止所有正在运行的容器
			        docker stop $(docker ps -q) 2>/dev/null
			        # 删除所有容器
			        docker rm $(docker ps -a -q) 2>/dev/null
			        # 删除所有镜像
			        docker rmi $(docker images -q) 2>/dev/null
			        # 清除所有未使用的网络
			        docker network prune -f
			        # 根据系统选择合适的卸载命令
			        if [ -f "/etc/debian_version" ]; then
			            sudo apt-get purge docker-ce docker-ce-cli containerd.io docker-compose-plugin
			        elif [ -f "/etc/redhat-release" ]; then
			            yum remove -y docker docker-client docker-client-latest docker-common docker-latest \
			            docker-latest-logrotate docker-logrotate docker-engine
			        fi
			        # 删除Docker的数据和配置文件
	   			sudo rm -rf /var/lib/docker
       				sudo rm -rf /var/lib/containerd
			        ;;
			    [Nn])
			        ;;
			    *)
			        echo "无效的选择，请输入 Y 或 N。"
			        ;;
			esac
   			;;
                    0)
                        solin
                        ;;
                    *)
                        echo "无效的选项，请重新输入！"
                        ;;
                esac
			break_end
            done
            ;;
        5)
            while true; do
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
			check_port
 		        install_dependency
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
                        solin
                        ;;
                    *)
                        echo "无效的选项，请重新输入！"
                        ;;
                esac
			break_end  # 跳出循环，退出菜单
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
            exit
            ;;
        *)
            echo "无效的选项，请重新输入！"
            ;;
    esac
    	   break_end
done
