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
    ipv4_address=$(curl -s ipv4.ip.sb)
}

# 函数: 获取IPv6地址
ipv6_address() {
	ipv6_address=$(curl -s --max-time 2 ipv6.ip.sb)
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
    echo "公网IPv4地址: $ipv4_address"
    echo "公网IPv6地址: $ipv6_address"
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

# 定义安装软件包函数
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

# 安装依赖
install_dependency() {
	clear
	install wget socat unzip tar 
}

install_ldnmp() {
	cd /home/web && docker-compose up -d
	clear
	echo "正在配置LDNMP环境，请耐心稍等……"

	# 定义要执行的命令
	commands=(
		"docker exec php apt update > /dev/null 2>&1"
		"docker exec php apt install -y libmariadb-dev-compat libmariadb-dev libzip-dev libmagickwand-dev imagemagick > /dev/null 2>&1"
		"docker exec php docker-php-ext-install mysqli pdo_mysql zip exif gd intl bcmath opcache > /dev/null 2>&1"
		"docker exec php pecl install imagick > /dev/null 2>&1"
		"docker exec php sh -c 'echo \"extension=imagick.so\" > /usr/local/etc/php/conf.d/imagick.ini' > /dev/null 2>&1"
		"docker exec php pecl install redis > /dev/null 2>&1"
		"docker exec php sh -c 'echo \"extension=redis.so\" > /usr/local/etc/php/conf.d/docker-php-ext-redis.ini' > /dev/null 2>&1"
		"docker exec php sh -c 'echo \"upload_max_filesize=50M \\n post_max_size=50M\" > /usr/local/etc/php/conf.d/uploads.ini' > /dev/null 2>&1"
		"docker exec php sh -c 'echo \"memory_limit=256M\" > /usr/local/etc/php/conf.d/memory.ini' > /dev/null 2>&1"
		"docker exec php sh -c 'echo \"max_execution_time=1200\" > /usr/local/etc/php/conf.d/max_execution_time.ini' > /dev/null 2>&1"
		"docker exec php sh -c 'echo \"max_input_time=600\" > /usr/local/etc/php/conf.d/max_input_time.ini' > /dev/null 2>&1"

		"docker exec php74 apt update > /dev/null 2>&1"
		"docker exec php74 apt install -y libmariadb-dev-compat libmariadb-dev libzip-dev libmagickwand-dev imagemagick > /dev/null 2>&1"
		"docker exec php74 docker-php-ext-install mysqli pdo_mysql zip gd intl bcmath opcache > /dev/null 2>&1"
		"docker exec php74 pecl install imagick > /dev/null 2>&1"
		"docker exec php74 sh -c 'echo \"extension=imagick.so\" > /usr/local/etc/php/conf.d/imagick.ini' > /dev/null 2>&1"
		"docker exec php74 pecl install redis > /dev/null 2>&1"
		"docker exec php74 sh -c 'echo \"extension=redis.so\" > /usr/local/etc/php/conf.d/docker-php-ext-redis.ini' > /dev/null 2>&1"
		"docker exec php74 sh -c 'echo \"upload_max_filesize=50M \\n post_max_size=50M\" > /usr/local/etc/php/conf.d/uploads.ini' > /dev/null 2>&1"
		"docker exec php74 sh -c 'echo \"memory_limit=256M\" > /usr/local/etc/php/conf.d/memory.ini' > /dev/null 2>&1"
		"docker exec php74 sh -c 'echo \"max_execution_time=1200\" > /usr/local/etc/php/conf.d/max_execution_time.ini' > /dev/null 2>&1"
		"docker exec php74 sh -c 'echo \"max_input_time=600\" > /usr/local/etc/php/conf.d/max_input_time.ini' > /dev/null 2>&1"

		"docker exec nginx chmod -R 777 /var/www/html"
		"docker exec php chmod -R 777 /var/www/html"
		"docker exec php74 chmod -R 777 /var/www/html"

		"docker restart php > /dev/null 2>&1"
		"docker restart php74 > /dev/null 2>&1"
		"docker restart nginx > /dev/null 2>&1"
	)

	total_commands=${#commands[@]}  # 计算总命令数

	for ((i = 0; i < total_commands; i++)); do
		command="${commands[i]}"
		eval $command  # 执行命令

		# 打印百分比和进度条
		percentage=$(( (i + 1) * 100 / total_commands ))
		completed=$(( percentage / 2 ))
		remaining=$(( 50 - completed ))
		progressBar="["
		for ((j = 0; j < completed; j++)); do
			progressBar+="#"
		done
		for ((j = 0; j < remaining; j++)); do
			progressBar+="."
		done
		progressBar+="]"
		echo -ne "\r[$percentage%] $progressBar"
	done

	echo  # 打印换行，以便输出不被覆盖


	clear
	echo "LDNMP环境安装完毕"
	echo "------------------------"

	# 获取nginx版本
	nginx_version=$(docker exec nginx nginx -v 2>&1)
	nginx_version=$(echo "$nginx_version" | grep -oP "nginx/\K[0-9]+\.[0-9]+\.[0-9]+")
	echo -n "nginx : v$nginx_version"

	# 获取mysql版本
	dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
	mysql_version=$(docker exec mysql mysql -u root -p"$dbrootpasswd" -e "SELECT VERSION();" 2>/dev/null | tail -n 1)
	echo -n "            mysql : v$mysql_version"

	# 获取php版本
	php_version=$(docker exec php php -v 2>/dev/null | grep -oP "PHP \K[0-9]+\.[0-9]+\.[0-9]+")
	echo -n "            php : v$php_version"

	# 获取redis版本
	redis_version=$(docker exec redis redis-server -v 2>&1 | grep -oP "v=+\K[0-9]+\.[0-9]+")
	echo "            redis : v$redis_version"

	echo "------------------------"
	echo ""
}

install_certbot() {
	install certbot

	# 切换到一个一致的目录（例如，家目录）
	cd ~ || exit

	# 下载并使脚本可执行
	curl -O https://raw.githubusercontent.com/zxl2008gz/sh/main/auto_cert_renewal.sh
	chmod +x auto_cert_renewal.sh

	# 安排每日午夜运行脚本
	echo "0 0 * * * cd ~ && ./auto_cert_renewal.sh" | crontab -
}

default_server_ssl() {
	install openssl
	openssl req -x509 -nodes -newkey rsa:2048 -keyout /home/web/certs/default_server.key -out /home/web/certs/default_server.crt -days 5475 -subj "/C=US/ST=State/L=City/O=Organization/OU=Organizational Unit/CN=Common Name"
}

nginx_status() {

    nginx_container_name="nginx"

    # 获取容器的状态
    container_status=$(docker inspect -f '{{.State.Status}}' "$nginx_container_name" 2>/dev/null)

    # 获取容器的重启状态
    container_restart_count=$(docker inspect -f '{{.RestartCount}}' "$nginx_container_name" 2>/dev/null)

    # 检查容器是否在运行，并且没有处于"Restarting"状态
    if [ "$container_status" == "running" ]; then
        echo ""
    else
        rm -r /home/web/html/$yuming >/dev/null 2>&1
        rm /home/web/conf.d/$yuming.conf >/dev/null 2>&1
        rm /home/web/certs/${yuming}_key.pem >/dev/null 2>&1
        rm /home/web/certs/${yuming}_cert.pem >/dev/null 2>&1
        docker restart nginx >/dev/null 2>&1
        echo -e "\e[1;31m检测到域名证书申请失败，请检测域名是否正确解析或更换域名重新尝试！\e[0m"
    fi
}


# 添加域名
add_yuming() {
	ipv4_address
	echo -e "先将域名解析到本机IP: \033[33m$ipv4_address\033[0m"
	read -p "请输入你解析的域名: " yuming
}

iptables_open() {
	iptables -P INPUT ACCEPT
	iptables -P FORWARD ACCEPT
	iptables -P OUTPUT ACCEPT
	iptables -F
}

#获取SSL证书
install_ssltls() {
	docker stop nginx > /dev/null 2>&1
	iptables_open
	cd ~
	certbot certonly --standalone -d $yuming --email your@email.com --agree-tos --no-eff-email --force-renewal
	cp /etc/letsencrypt/live/$yuming/cert.pem /home/web/certs/${yuming}_cert.pem
	cp /etc/letsencrypt/live/$yuming/privkey.pem /home/web/certs/${yuming}_key.pem
	docker start nginx > /dev/null 2>&1
}

# 添加数据库
add_db() {
	dbname=$(echo "$yuming" | sed -e 's/[^A-Za-z0-9]/_/g')
	dbname="${dbname}"

	dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
	dbuse=$(grep -oP 'MYSQL_USER:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
	dbusepasswd=$(grep -oP 'MYSQL_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
	docker exec mysql mysql -u root -p"$dbrootpasswd" -e "CREATE DATABASE $dbname; GRANT ALL PRIVILEGES ON $dbname.* TO \"$dbuse\"@\"%\";"
}

# 定义反向代理
reverse_proxy() {
	ipv4_address
	wget -O /home/web/conf.d/$yuming.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/reverse-proxy.conf
	sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf
	sed -i "s/0.0.0.0/$ipv4_address/g" /home/web/conf.d/$yuming.conf
	sed -i "s/0000/$duankou/g" /home/web/conf.d/$yuming.conf
	docker restart nginx
}

#重启 LDNMP
restart_ldnmp() {
	docker exec nginx chmod -R 777 /var/www/html
	docker exec php chmod -R 777 /var/www/html
	docker exec php74 chmod -R 777 /var/www/html

	docker restart php
	docker restart php74
	docker restart nginx
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
				echo "7. 安装vaultwarden密码管理平台"
				echo "8. 安装epusdt收款地址"			
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
						install_docker
						install_certbot
						# 创建必要的目录和文件
						cd /home && mkdir -p web/html web/mysql web/certs web/conf.d web/redis web/log/nginx && touch web/docker-compose.yml
						wget -O  /home/web/nginx.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/LNMP/nginx.conf
						wget -O /home/web/conf.d/default.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/LNMP/default.conf
						default_server_ssl

						wget -O /home/web/docker-compose.yml https://raw.githubusercontent.com/zxl2008gz/docker/main/LNMP/docker-compose.yml
						dbrootpasswd=$(openssl rand -base64 16) && dbuse=$(openssl rand -hex 4) && dbusepasswd=$(openssl rand -base64 8)
						# 在 docker-compose.yml 文件中进行替换
						sed -i "s/mysqlwebroot/$dbrootpasswd/g" /home/web/docker-compose.yml
						sed -i "s/mysqlpasswd/$dbusepasswd/g" /home/web/docker-compose.yml
						sed -i "s/mysqluse/$dbuse/g" /home/web/docker-compose.yml
						install_ldnmp
						;;
                    2)
                        clear
						# 安装WordPress
						add_yuming
						install_ssltls
						add_db

						wget -O /home/web/conf.d/$yuming.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/wordpress/wordpress.com.conf
						sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf

						cd /home/web/html
						mkdir $yuming
						cd $yuming
						wget -O latest.zip https://cn.wordpress.org/latest-zh_CN.zip
						unzip latest.zip
						rm latest.zip

						echo "define('FS_METHOD', 'direct'); define('WP_REDIS_HOST', 'redis'); define('WP_REDIS_PORT', '6379');" >> /home/web/html/$yuming/wordpress/wp-config-sample.php

						restart_ldnmp

						clear
						echo "您的WordPress搭建好了！"
						echo "https://$yuming"
						echo "------------------------"
						echo "WP安装信息如下: "
						echo "数据库名: $dbname"
						echo "用户名: $dbuse"
						echo "密码: $dbusepasswd"
						echo "数据库地址: mysql"
						echo "表前缀: wp_"
						nginx_status
                        ;;
                    3)
                        clear
						# 安装可道云桌面
						add_yuming
						install_ssltls
						add_db

						wget -O /home/web/conf.d/$yuming.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/kodbox/kodbox.com.conf
						sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf

						cd /home/web/html
						mkdir $yuming
						cd $yuming

						wget https://github.com/kalcaddle/kodbox/archive/refs/tags/1.42.04.zip
						unzip -o 1.42.04.zip
						rm 1.42.04.zip

						restart_ldnmp

						clear
						echo "您的可道云桌面搭建好了！"
						echo "https://$yuming"
						echo "------------------------"
						echo "安装信息如下: "
						echo "数据库地址: mysql"
						echo "用户名: $dbuse"
						echo "密码: $dbusepasswd"
						echo "数据库名: $dbname"
						echo "redis主机: redis"
						nginx_status     
                        ;;
                    4)
                        clear
						# 安装独角数发卡网
						add_yuming
						install_ssltls
						add_db
	 
						wget -O /home/web/conf.d/$yuming.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/dujiaoka/dujiaoka.com.conf
	  
						sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf

						cd /home/web/html
						mkdir $yuming
						cd $yuming

						wget https://github.com/assimon/dujiaoka/releases/download/2.0.6/2.0.6-antibody.tar.gz && tar -zxvf 2.0.6-antibody.tar.gz && rm 2.0.6-antibody.tar.gz

						restart_ldnmp

						clear
						echo "您的独角数卡网站搭建好了！"
						echo "https://$yuming"
						echo "------------------------"
						echo "安装信息如下: "
						echo "数据库地址: mysql"
						echo "数据库端口: 3306"
						echo "数据库名: $dbname"
						echo "用户名: $dbuse"
						echo "密码: $dbusepasswd"
						echo ""
						echo "redis地址: redis"
						echo "redis密码: 默认不填写"
						echo "redis端口: 6379"
						echo ""
						echo "网站url: https://$yuming"
						echo "后台登录路径: /admin"
						echo "------------------------"
						echo "用户名: admin"
						echo "密码: admin"
						echo "------------------------"
						echo "登录时右上角如果出现红色error0请使用如下命令: "
						echo "我也很气愤独角数卡为啥这么麻烦，会有这样的问题！"
						echo "sed -i 's/ADMIN_HTTPS=false/ADMIN_HTTPS=true/g' /home/web/html/$yuming/dujiaoka/.env"
						nginx_status     			
                        ;;
                    5)
                        clear
						# 安装LobeChat聊天网站
						add_yuming
						install_ssltls

						cd /home/web/html
						mkdir $yuming
						cd $yuming
						
						dbusepasswd=$(grep -oP 'MYSQL_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
						read -p "请输入你的OPENAI_API_KEY: " apikey
	 
						docker run  -d --name lobe-chat \
						--restart always \
						-p 8089:3210 \
						-e OPENAI_API_KEY=$apikey \
						-e ACCESS_CODE=$dbusepasswd \
						-e HIDE_USER_API_KEY=1 \
						-e BASE_URL=https://api.openai.com \
						lobehub/lobe-chat

						duankou=8089
						reverse_proxy

						clear
						echo "您的LobeChat聊天网站搭建好了！"
						echo "https://$yuming"
						nginx_status
                        ;;
                    6)
                        clear
						# 安装GeminiPro聊天网站
						add_yuming
						install_ssltls

						cd /home/web/html
						mkdir $yuming
						cd $yuming						
						
						read -p "请输入你的GEMINI_API_KEY: " apikey

						docker run --name geminiprochat \
						--restart always \
						-p 3030:3000 \
						-itd \
						-e GEMINI_API_KEY=$apikey \
						howie6879/geminiprochat:v0.1.0

						duankou=3030
						reverse_proxy
	 
						clear
						echo "您的GeminiPro聊天网站搭建好了！"
						echo "https://$yuming"
						nginx_status	 		
                        ;;	
                    7)
						clear
                        # 安装vaultwarden密码管理平台
						add_yuming
						install_ssltls
	 
						cd /home/web/html
						mkdir $yuming
						cd $yuming
						mkdir -p /home/web/html/$yuming/vaultwarden

						docker run -d --name vaultwarden \
						--restart=always \
						-p 8888:8080 \
						-e ROCKET_PORT=8080 \
						-e WEBSOCKET_ENABLED=true \
						-e SIGNUPS_ALLOWED=true \
						-e LOGIN_RATELIMIT_MAX_BURST=10 \
						-e LOGIN_RATELIMIT_SECONDS=60 \
						-e ADMIN_RATELIMIT_MAX_BURST=10 \
						-e ADMIN_RATELIMIT_SECONDS=60 \
						-e ADMIN_SESSION_LIFETIME=20 \
						-e SENDS_ALLOWED=true \
						-e EMERGENCY_ACCESS_ALLOWED=true \
						-e WEB_VAULT_ENABLED=true \
						-v /home/web/html/$yuming/vaultwarden:/data \
						vaultwarden/server:latest

						duankou=8888
						reverse_proxy   		

						clear
						echo "您的vaultwarden聊天网站搭建好了！"
						echo "https://$yuming"
						nginx_status   			
                        ;;
                    8)
                        clear
						# 安装epusdt收款地址
						add_yuming
						install_ssltls

						cd /home/web/html
						mkdir $yuming
						cd $yuming
						mkdir -p /home/web/html/$yuming/epusdt
						cd epusdt
						chmod 777 -R /home/web/html/$yuming/epusdt
			 
						dbname="epusdt"
			 
						dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
						dbuse=$(grep -oP 'MYSQL_USER:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
						dbusepasswd=$(grep -oP 'MYSQL_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
						docker exec mysql mysql -u root -p"$dbrootpasswd" -e "CREATE DATABASE $dbname; GRANT ALL PRIVILEGES ON $dbname.* TO \"$dbuse\"@\"%\";"

						wget -O /home/web/html/$yuming/epusdt/epusdt.sql https://raw.githubusercontent.com/zxl2008gz/docker/main/epusdt/epusdt.sql
						# 设定数据文件的路径，你需要根据实际情况修改此路径
						datafile="/home/web/html/${yuming}/epusdt/epusdt.sql"
	
						# 导入数据
						docker exec -i mysql mysql -u "$dbuse" -p"$dbusepasswd" "$dbname" < "$datafile"		  		
 		
						wget -O /home/web/html/$yuming/epusdt/epusdt.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/epusdt/epusdt.conf
						sed -i "s/yuming.com/$yuming/g" /home/web/html/$yuming/epusdt/epusdt.conf	
						sed -i "s/mysql_user=epusdt/mysql_user=$dbuse/g" /home/web/html/$yuming/epusdt/epusdt.conf	
						sed -i "s/changeyourpassword/$dbusepasswd/g" /home/web/html/$yuming/epusdt/epusdt.conf	
						read -p "请输入你的tg机器人token: " tg_bot_token
						sed -i "s/你的tg机器人token/$tg_bot_token/g" /home/web/html/$yuming/epusdt/epusdt.conf
						read -p "请输入你的tgid: " tg_id
						sed -i "s/你的tgid/$tg_id/g" /home/web/html/$yuming/epusdt/epusdt.conf      

						docker run -d \
						--name epusdt \
						--restart=always \
						--network web_default \
						-p 8000:8000 \
						-e mysql_host=mysql \
						-e mysql_database=$dbname \
						-e mysql_user=$dbuse \
						-e mysql_passwd=$dbusepasswd \
						-v $(pwd)/epusdt.conf:/app/.env \
						stilleshan/epusdt

						duankou=8000
						reverse_proxy   		

						clear
						echo "您的epusdt收款地址网站搭建好了！"
						echo "https://$yuming"
						echo "------------------------"
						echo "epusdt安装信息如下: "
						echo "数据库名: $dbname"
						echo "用户名: $dbuse"
						echo "密码: $dbusepasswd"
						echo "数据库地址: mysql"
						echo "商户ID: $dbusepasswd"
						echo "商户密钥: https://$yuming/api/v1/order/create-transaction"
						nginx_status   		
                        ;;						
                    21)
						clear
                        # 仅安装nginx
						check_port
						install_dependency
						install_docker
						install_certbot
						cd /home && mkdir -p web/html web/mysql web/certs web/conf.d web/redis web/log/nginx && touch web/docker-compose.yml
    			
						wget -O  /home/web/nginx.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/LNMP/nginx.conf
						wget -O /home/web/conf.d/default.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/LNMP/default.conf
						default_server_ssl
	  
						docker rm -f nginx >/dev/null 2>&1
						docker rmi nginx >/dev/null 2>&1
						docker run -d --name nginx --restart always -p 80:80 -p 443:443 -v /home/web/nginx.conf:/etc/nginx/nginx.conf -v /home/web/conf.d:/etc/nginx/conf.d -v /home/web/certs:/etc/nginx/certs -v /home/web/html:/var/www/html -v /home/web/log/nginx:/var/log/nginx nginx

						clear
						nginx_version=$(docker exec nginx nginx -v 2>&1)
						nginx_version=$(echo "$nginx_version" | grep -oP "nginx/\K[0-9]+\.[0-9]+\.[0-9]+")
						echo "nginx已安装完成"
						echo "当前版本: v$nginx_version"
						echo ""
						;;		
                    22)
                        clear
						# 站点重定向
						ipv4_address
						echo -e "先将域名解析到本机IP: \033[33m$ipv4_address\033[0m"
						read -p "请输入你的域名: " yuming
						read -p "请输入跳转域名: " reverseproxy

						install_ssltls

						wget -O /home/web/conf.d/$yuming.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/redirect
						sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf
						sed -i "s/baidu.com/$reverseproxy/g" /home/web/conf.d/$yuming.conf

						docker restart nginx

						clear
						echo "您的重定向网站做好了！"
						echo "https://$yuming"
						nginx_status      
                        ;;		
                    23)
                        clear
						# 站点反向代理
						ipv4_address
						echo -e "先将域名解析到本机IP: \033[33m$ipv4_address\033[0m"
						read -p "请输入你的域名: " yuming
						read -p "请输入你的反代IP: " reverseproxy
						read -p "请输入你的反代端口: " port
					
						install_ssltls

						wget -O /home/web/conf.d/$yuming.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/reverse-proxy.conf
						sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf
						sed -i "s/0.0.0.0/$reverseproxy/g" /home/web/conf.d/$yuming.conf
						sed -i "s/0000/$port/g" /home/web/conf.d/$yuming.conf

						docker restart nginx

						clear
						echo "您的反向代理网站做好了！"
						echo "https://$yuming"
						nginx_status
                        ;;		
                    24)
                        clear
						# 自定义静态站点
						add_yuming
						install_ssltls

						wget -O /home/web/conf.d/$yuming.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/html.conf
						sed -i "s/yuming.com/$yuming/g" /home/web/conf.d/$yuming.conf

						cd /home/web/html
						mkdir $yuming
						cd $yuming

						install lrzsz
						clear
						echo -e "目前只允许上传\033[33mindex.html\033[0m文件，请提前准备好，按任意键继续..."
						read -n 1 -s -r -p ""
						rz

						docker exec nginx chmod -R 777 /var/www/html
						docker restart nginx

						clear
						echo "您的静态网站搭建好了！"
						echo "https://$yuming"
						nginx_status
                        ;;		
                    31)
                        # 站点数据管理
						while true; do
							clear
							echo "LDNMP环境"
							echo "------------------------"
							# 获取nginx版本
							nginx_version=$(docker exec nginx nginx -v 2>&1)
							nginx_version=$(echo "$nginx_version" | grep -oP "nginx/\K[0-9]+\.[0-9]+\.[0-9]+")
							echo -n "nginx : v$nginx_version"
							# 获取mysql版本
							dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
							mysql_version=$(docker exec mysql mysql -u root -p"$dbrootpasswd" -e "SELECT VERSION();" 2>/dev/null | tail -n 1)
							echo -n "            mysql : v$mysql_version"
							# 获取php版本
							php_version=$(docker exec php php -v 2>/dev/null | grep -oP "PHP \K[0-9]+\.[0-9]+\.[0-9]+")
							echo -n "            php : v$php_version"
							# 获取redis版本
							redis_version=$(docker exec redis redis-server -v 2>&1 | grep -oP "v=+\K[0-9]+\.[0-9]+")
							echo "            redis : v$redis_version"
							echo "------------------------"
							echo ""


							# ls -t /home/web/conf.d | sed 's/\.[^.]*$//'
							echo "站点信息                      证书到期时间"
							echo "------------------------"
							for cert_file in /home/web/certs/*_cert.pem; do
								domain=$(basename "$cert_file" | sed 's/_cert.pem//')
								if [ -n "$domain" ]; then
									expire_date=$(openssl x509 -noout -enddate -in "$cert_file" | awk -F'=' '{print $2}')
									formatted_date=$(date -d "$expire_date" '+%Y-%m-%d')
									printf "%-30s%s\n" "$domain" "$formatted_date"
								fi
							done

							echo "------------------------"
							echo ""
							echo "数据库信息"
							echo "------------------------"
							dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
							docker exec mysql mysql -u root -p"$dbrootpasswd" -e "SHOW DATABASES;" 2> /dev/null | grep -Ev "Database|information_schema|mysql|performance_schema|sys"

							echo "------------------------"
							echo ""
							echo "操作"
							echo "------------------------"
							echo "1. 申请/更新域名证书               2. 更换站点域名"
							echo -e "3. 清理站点缓存                    4. 查看站点分析报告 \033[33mNEW\033[0m"
							echo "------------------------"
							echo "7. 删除指定站点                    8. 删除指定数据库"
							echo "------------------------"
							echo "0. 返回上一级选单"
							echo "------------------------"
							read -p "请输入你的选择: " sub_choice
							case $sub_choice in
								1)
									read -p "请输入你的域名: " yuming
									install_ssltls

									;;

								2)
									read -p "请输入旧域名: " oddyuming
									read -p "请输入新域名: " yuming
									mv /home/web/conf.d/$oddyuming.conf /home/web/conf.d/$yuming.conf
									sed -i "s/$oddyuming/$yuming/g" /home/web/conf.d/$yuming.conf
									mv /home/web/html/$oddyuming /home/web/html/$yuming

									rm /home/web/certs/${oddyuming}_key.pem
									rm /home/web/certs/${oddyuming}_cert.pem
									install_ssltls

									;;
								3)
									docker exec -it nginx rm -rf /var/cache/nginx
									docker restart nginx
									;;
								4)
									install goaccess
									goaccess --log-format=COMBINED /home/web/log/nginx/access.log

									;;

								7)
									read -p "请输入你的域名: " yuming
									rm -r /home/web/html/$yuming
									rm /home/web/conf.d/$yuming.conf
									rm /home/web/certs/${yuming}_key.pem
									rm /home/web/certs/${yuming}_cert.pem
									docker restart nginx
									;;
								8)
									read -p "请输入数据库名: " shujuku
									dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
									docker exec mysql mysql -u root -p"$dbrootpasswd" -e "DROP DATABASE $shujuku;" 2> /dev/null
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
                    32)
                        clear
						# 备份全站数据
						cd /home/ && tar czvf web_$(date +"%Y%m%d%H%M%S").tar.gz web

						while true; do
							clear
							read -p "要传送文件到远程服务器吗？(Y/N): " choice
							case "$choice" in
								[Yy])
									read -p "请输入远端服务器IP:  " remote_ip
									if [ -z "$remote_ip" ]; then
										echo "错误: 请输入远端服务器IP。"
										continue
									fi
									latest_tar=$(ls -t /home/*.tar.gz | head -1)
									if [ -n "$latest_tar" ]; then
										ssh-keygen -f "/root/.ssh/known_hosts" -R "$remote_ip"
										sleep 2  # 添加等待时间
										scp -o StrictHostKeyChecking=no "$latest_tar" "root@$remote_ip:/home/"
										echo "文件已传送至远程服务器home目录。"
									else
										echo "未找到要传送的文件。"
									fi
									break
									;;
								[Nn])
									break
									;;
								*)
									echo "无效的选择，请输入 Y 或 N。"
									;;
							esac
						done
                        ;;		
                    33)
                        # 定时远程备份
						clear
						read -p "输入远程服务器IP: " useip
						read -p "输入远程服务器密码: " usepasswd
						
						wget -O ${useip}_beifen.sh https://raw.githubusercontent.com/zxl2008gz/sh/main/benfen.sh > /dev/null 2>&1
						chmod +x ${useip}_beifen.sh
						
						sed -i "s/0.0.0.0/$useip/g" ${useip}_beifen.sh
						sed -i "s/123456/$usepasswd/g" ${useip}_beifen.sh
						
						echo "------------------------"
						echo "1. 每周备份                 2. 每天备份"
						read -p "请输入你的选择: " dingshi
			
						case $dingshi in
							1)
								read -p "选择每周备份的星期几 (0-6，0代表星期日): " weekday
								(crontab -l ; echo "0 0 * * $weekday ./${useip}_beifen.sh") | crontab - > /dev/null 2>&1
								;;
							2)
								read -p "选择每天备份的时间（小时，0-23）: " hour
								(crontab -l ; echo "0 $hour * * * ./${useip}_beifen.sh") | crontab - > /dev/null 2>&1
								;;
							*)
								break  # 跳出
								;;
						esac
						
						install sshpass
                        ;;		
                    34)
                        # 还原全站数据
						clear
						cd /home/ && ls -t /home/*.tar.gz | head -1 | xargs -I {} tar -xzf {}
						check_port
						install_dependency
						install_docker
						install_certbot
						install_ldnmp
                        ;;		
                    35)
                        # 站点防御程序
						if [ -x "$(command -v fail2ban-client)" ] && [ -d "/etc/fail2ban" ]; then
							while true; do
								clear
								echo "服务器防御程序已启动"
								echo "------------------------"
								echo "1. 开启SSH防暴力破解              2. 关闭SSH防暴力破解"
								echo "3. 开启网站保护                   4. 关闭网站保护"
								echo "------------------------"
								echo "5. 查看SSH拦截记录                6. 查看网站拦截记录"
								echo "7. 查看防御规则列表               8. 查看日志实时监控"
								echo "------------------------"
								echo "9. 卸载防御程序"
								echo "------------------------"
								echo "0. 退出"
								echo "------------------------"
								read -p "请输入你的选择: " sub_choice
								case $sub_choice in
									1)
										sed -i 's/false/true/g' /etc/fail2ban/jail.d/sshd.local
										systemctl restart fail2ban
										sleep 1
										fail2ban-client status
										;;
									2)
										sed -i 's/true/false/g' /etc/fail2ban/jail.d/sshd.local
										systemctl restart fail2ban
										sleep 1
										fail2ban-client status
										;;
									3)
										sed -i 's/false/true/g' /etc/fail2ban/jail.d/nginx.local
										systemctl restart fail2ban
										sleep 1
										fail2ban-client status
										;;
									4)
										sed -i 's/true/false/g' /etc/fail2ban/jail.d/nginx.local
										systemctl restart fail2ban
										sleep 1
										fail2ban-client status
										;;
									5)
										echo "------------------------"
										fail2ban-client status sshd
										echo "------------------------"
										;;
									6)
										echo "------------------------"
										fail2ban-client status nginx-bad-request
										echo "------------------------"
										fail2ban-client status nginx-botsearch
										echo "------------------------"
										fail2ban-client status nginx-http-auth
										echo "------------------------"
										fail2ban-client status nginx-limit-req
										echo "------------------------"
										fail2ban-client status php-url-fopen
										echo "------------------------"
										;;

									7)
										fail2ban-client status
										;;
									8)
										tail -f /var/log/fail2ban.log

										;;
									9)
										remove fail2ban
										break
										;;
									0)
										break
										;;
									*)
										echo "无效的选择，请重新输入。"
										;;
								esac
									break_end
							done
						else
							clear
							# 安装Fail2ban
							if [ -f /etc/debian_version ]; then
								# Debian/Ubuntu系统
								install fail2ban
							elif [ -f /etc/redhat-release ]; then
								# CentOS系统
								install epel-release fail2ban
							else
								echo "不支持的操作系统类型"
								exit 1
							fi

							# 启动Fail2ban
							systemctl start fail2ban

							# 设置Fail2ban开机自启
							systemctl enable fail2ban

							# 配置Fail2ban
							rm -rf /etc/fail2ban/jail.d/*
							cd /etc/fail2ban/jail.d/
							curl -sS -O https://raw.githubusercontent.com/zxl2008gz/sh/main/sshd.local
							systemctl restart fail2ban
							docker rm -f nginx

							wget -O /home/web/nginx.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/LNMP/nginx.conf
							wget -O /home/web/conf.d/default.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/LNMP/default.conf
							default_server_ssl
							docker run -d --name nginx --restart always --network web_default -p 80:80 -p 443:443 -v /home/web/nginx.conf:/etc/nginx/nginx.conf -v /home/web/conf.d:/etc/nginx/conf.d -v /home/web/certs:/etc/nginx/certs -v /home/web/html:/var/www/html -v /home/web/log/nginx:/var/log/nginx nginx
							docker exec -it nginx chmod -R 777 /var/www/html

							# 获取宿主机当前时区
							HOST_TIMEZONE=$(timedatectl show --property=Timezone --value)

							# 调整多个容器的时区
							docker exec -it nginx ln -sf "/usr/share/zoneinfo/$HOST_TIMEZONE" /etc/localtime
							docker exec -it php ln -sf "/usr/share/zoneinfo/$HOST_TIMEZONE" /etc/localtime
							docker exec -it php74 ln -sf "/usr/share/zoneinfo/$HOST_TIMEZONE" /etc/localtime
							docker exec -it mysql ln -sf "/usr/share/zoneinfo/$HOST_TIMEZONE" /etc/localtime
							docker exec -it redis ln -sf "/usr/share/zoneinfo/$HOST_TIMEZONE" /etc/localtime
							rm -rf /home/web/log/nginx/*
							docker restart nginx

							curl -sS -O https://raw.githubusercontent.com/zxl2008gz/sh/main/nginx.local
							systemctl restart fail2ban
							sleep 1
							fail2ban-client status
							echo "防御程序已开启"
						fi			
                        ;;		
                    36)
                        # 优化LDNMP环境
						while true; do
							clear
							echo "优化LDNMP环境"
							echo "------------------------"
							echo "1. 标准模式              2. 高性能模式 (推荐2H2G以上)"
							echo "------------------------"
							echo "0. 退出"
							echo "------------------------"
							read -p "请输入你的选择: " sub_choice
							case $sub_choice in
								1)
									# nginx调优
									sed -i 's/worker_connections.*/worker_connections 1024;/' /home/web/nginx.conf

									# php调优
									wget -O /home/www.conf https://raw.githubusercontent.com/zxl2008gz/sh/main/www-1.conf
									docker cp /home/www.conf php:/usr/local/etc/php-fpm.d/www.conf
									docker cp /home/www.conf php74:/usr/local/etc/php-fpm.d/www.conf
									rm -rf /home/www.conf

									# mysql调优
									wget -O /home/custom_mysql_config.cnf https://raw.githubusercontent.com/zxl2008gz/sh/main/custom_mysql_config-1.cnf
									docker cp /home/custom_mysql_config.cnf mysql:/etc/mysql/conf.d/
									rm -rf /home/custom_mysql_config.cnf

									docker restart nginx
									docker restart php
									docker restart php74
									docker restart mysql

									echo "LDNMP环境已设置成 标准模式"

									;;
								2)

									# nginx调优
									sed -i 's/worker_connections.*/worker_connections 131072;/' /home/web/nginx.conf

									# php调优
									wget -O /home/www.conf https://raw.githubusercontent.com/zxl2008gz/sh/main/www.conf
									docker cp /home/www.conf php:/usr/local/etc/php-fpm.d/www.conf
									docker cp /home/www.conf php74:/usr/local/etc/php-fpm.d/www.conf
									rm -rf /home/www.conf

									# mysql调优
									wget -O /home/custom_mysql_config.cnf https://raw.githubusercontent.com/zxl2008gz/sh/main/custom_mysql_config.cnf
									docker cp /home/custom_mysql_config.cnf mysql:/etc/mysql/conf.d/
									rm -rf /home/custom_mysql_config.cnf

									docker restart nginx
									docker restart php
									docker restart php74
									docker restart mysql

									echo "LDNMP环境已设置成 高性能模式"

									;;
								0)
									break
									;;
								*)
									echo "无效的选择，请重新输入。"
									;;
							esac
								break_end
							
						done
                        ;;		
                    37)
                        # 更新LDNMP环境
						clear
						docker rm -f nginx php php74 mysql redis
						docker rmi nginx php:fpm php:7.4.33-fpm mysql redis

						check_port
						install_dependency
						install_docker
						install_certbot
						install_ldnmp			
                        ;;		
                    38)
                        # 卸载LDNMP环境
						clear
						read -p "强烈建议先备份全部网站数据，再卸载LDNMP环境。确定删除所有网站数据吗？(Y/N): " choice
						case "$choice" in
							[Yy])
								docker rm -f nginx php php74 mysql redis
								docker rmi nginx php:fpm php:7.4.33-fpm mysql redis
								rm -r /home/web
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
					break_end  # 跳出循环，退出菜单
			done
			;;
        6)
            # 系统工具逻辑
			while true; do
				clear
				echo "▶ 系统工具"
				echo "------------------------"
				echo "1. 设置脚本启动快捷键"
				echo "------------------------"
				echo "2. 修改ROOT密码"
				echo "3. 开启ROOT密码登录模式"
				echo "4. 安装Python最新版"
				echo "5. 开放所有端口"
				echo "6. 修改SSH连接端口"
				echo "7. 优化DNS地址"
				echo "8. 一键重装系统"
				echo "9. 禁用ROOT账户创建新账户"
				echo "10. 切换优先ipv4/ipv6"
				echo "11. 查看端口占用状态"
				echo "12. 修改虚拟内存大小"
				echo "13. 用户管理"
				echo "14. 用户/密码生成器"
				echo "15. 系统时区调整"
				echo "16. 开启BBR3加速"
				echo "17. 防火墙高级管理器"
				echo "18. 修改主机名"
				echo "19. 切换系统更新源"
				echo -e "20. 定时任务管理 \033[33mNEW\033[0m"
				echo "------------------------"
				echo "99. 重启服务器"
				echo "------------------------"
				echo "0. 返回主菜单"
				echo "------------------------"
				read -p "请输入你的选择: " sub_choice

				case $sub_choice in
					1)
						clear
						read -p "请输入你的快捷按键: " kuaijiejian
						echo "alias $kuaijiejian='./solin.sh'" >> ~/.bashrc
						source ~/.bashrc
						echo "快捷键已设置"
						;;
	
					2)
						clear
						echo "设置你的ROOT密码"
						passwd
						;;
					3)
						clear
						echo "设置你的ROOT密码"
						passwd
						sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config;
						sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config;
						service sshd restart
						echo "ROOT登录设置完毕！"
						read -p "需要重启服务器吗？(Y/N): " choice
						case "$choice" in
							[Yy])
								reboot
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

						RED="\033[31m"
						GREEN="\033[32m"
						YELLOW="\033[33m"
						NC="\033[0m"

						# 系统检测
						OS=$(cat /etc/os-release | grep -o -E "Debian|Ubuntu|CentOS" | head -n 1)

						if [[ $OS == "Debian" || $OS == "Ubuntu" || $OS == "CentOS" ]]; then
							echo -e "检测到你的系统是 ${YELLOW}${OS}${NC}"
						else
							echo -e "${RED}很抱歉，你的系统不受支持！${NC}"
							exit 1
						fi

						# 检测安装Python3的版本
						VERSION=$(python3 -V 2>&1 | awk '{print $2}')

						# 获取最新Python3版本
						PY_VERSION=$(curl -s https://www.python.org/ | grep "downloads/release" | grep -o 'Python [0-9.]*' | grep -o '[0-9.]*')

						# 卸载Python3旧版本
						if [[ $VERSION == "3"* ]]; then
							echo -e "${YELLOW}你的Python3版本是${NC}${RED}${VERSION}${NC}，${YELLOW}最新版本是${NC}${RED}${PY_VERSION}${NC}"
							read -p "是否确认升级最新版Python3？默认不升级 [y/N]: " CONFIRM
							if [[ $CONFIRM == "y" ]]; then
								if [[ $OS == "CentOS" ]]; then
									echo ""
									rm-rf /usr/local/python3* >/dev/null 2>&1
								else
									apt --purge remove python3 python3-pip -y
									rm-rf /usr/local/python3*
								fi
							else
								echo -e "${YELLOW}已取消升级Python3${NC}"
								exit 1
							fi
						else
							echo -e "${RED}检测到没有安装Python3。${NC}"
							read -p "是否确认安装最新版Python3？默认安装 [Y/n]: " CONFIRM
							if [[ $CONFIRM != "n" ]]; then
								echo -e "${GREEN}开始安装最新版Python3...${NC}"
							else
								echo -e "${YELLOW}已取消安装Python3${NC}"
								exit 1
							fi
						fi

						# 安装相关依赖
						if [[ $OS == "CentOS" ]]; then
							yum update
							yum groupinstall -y "development tools"
							yum install wget openssl-devel bzip2-devel libffi-devel zlib-devel -y
						else
							apt update
							apt install wget build-essential libreadline-dev libncursesw5-dev libssl-dev libsqlite3-dev tk-dev libgdbm-dev libc6-dev libbz2-dev libffi-dev zlib1g-dev -y
						fi

						# 安装python3
						cd /root/
						wget https://www.python.org/ftp/python/${PY_VERSION}/Python-"$PY_VERSION".tgz
						tar -zxf Python-${PY_VERSION}.tgz
						cd Python-${PY_VERSION}
						./configure --prefix=/usr/local/python3
						make -j $(nproc)
						make install
						if [ $? -eq 0 ];then
							rm -f /usr/local/bin/python3*
							rm -f /usr/local/bin/pip3*
							ln -sf /usr/local/python3/bin/python3 /usr/bin/python3
							ln -sf /usr/local/python3/bin/pip3 /usr/bin/pip3
							clear
							echo -e "${YELLOW}Python3安装${GREEN}成功，${NC}版本为: ${NC}${GREEN}${PY_VERSION}${NC}"
						else
							clear
							echo -e "${RED}Python3安装失败！${NC}"
							exit 1
						fi
						cd /root/ && rm -rf Python-${PY_VERSION}.tgz && rm -rf Python-${PY_VERSION}
						;;
	
					5)
						clear
						iptables_open
						remove iptables-persistent ufw firewalld iptables-services > /dev/null 2>&1
						echo "端口已全部开放"

						;;
					6)
						clear
						#!/bin/bash

						# 去掉 #Port 的注释
						sed -i 's/#Port/Port/' /etc/ssh/sshd_config

						# 读取当前的 SSH 端口号
						current_port=$(grep -E '^ *Port [0-9]+' /etc/ssh/sshd_config | awk '{print $2}')

						# 打印当前的 SSH 端口号
						echo "当前的 SSH 端口号是: $current_port"

						echo "------------------------"

						# 提示用户输入新的 SSH 端口号
						read -p "请输入新的 SSH 端口号: " new_port

						# 备份 SSH 配置文件
						cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

						# 替换 SSH 配置文件中的端口号
						sed -i "s/Port [0-9]\+/Port $new_port/g" /etc/ssh/sshd_config

						# 重启 SSH 服务
						service sshd restart

						echo "SSH 端口已修改为: $new_port"

						clear
						iptables_open
						remove iptables-persistent ufw firewalld iptables-services > /dev/null 2>&1

						;;

	
					7)
						clear
						echo "当前DNS地址"
						echo "------------------------"
						cat /etc/resolv.conf
						echo "------------------------"
						echo ""
						# 询问用户是否要优化DNS设置
						read -p "是否要设置为Cloudflare和Google的DNS地址？(y/n): " choice

						if [ "$choice" == "y" ]; then
							# 定义DNS地址
							cloudflare_ipv4="1.1.1.1"
							google_ipv4="8.8.8.8"
							cloudflare_ipv6="2606:4700:4700::1111"
							google_ipv6="2001:4860:4860::8888"

							# 检查机器是否有IPv6地址
							ipv6_available=0
							if [[ $(ip -6 addr | grep -c "inet6") -gt 0 ]]; then
								ipv6_available=1
							fi

							# 设置DNS地址为Cloudflare和Google（IPv4和IPv6）
							echo "设置DNS为Cloudflare和Google"

							# 设置IPv4地址
							echo "nameserver $cloudflare_ipv4" > /etc/resolv.conf
							echo "nameserver $google_ipv4" >> /etc/resolv.conf

							# 如果有IPv6地址，则设置IPv6地址
							if [[ $ipv6_available -eq 1 ]]; then
								echo "nameserver $cloudflare_ipv6" >> /etc/resolv.conf
								echo "nameserver $google_ipv6" >> /etc/resolv.conf
							fi

							echo "DNS地址已更新"
							echo "------------------------"
							cat /etc/resolv.conf
							echo "------------------------"
						else
							echo "DNS设置未更改"
						fi
		
						;;
	
					8)
						clear
						echo "请备份数据，将为你重装系统，预计花费15分钟。"
						read -p "确定继续吗？(Y/N): " choice

						case "$choice" in
							[Yy])
								while true; do
									read -p "请选择要重装的系统:  1. Debian11 | 2. Debian12 | 3. Ubuntu20.04 : " sys_choice

									case "$sys_choice" in
										1)
											xitong="-d 11"
											break  # 结束循环
											;;
										2)
											xitong="-d 12"
											break  # 结束循环
											;;       			
										3)
											xitong="-u 20.04"
											break  # 结束循环
											;;
										*)
											echo "无效的选择，请重新输入。"
											;;
									esac
								done

								read -p "请输入你重装后的密码: " vpspasswd
								install wget
								bash <(wget --no-check-certificate -qO- 'https://raw.githubusercontent.com/MoeClub/Note/master/InstallNET.sh') $xitong -v 64 -p $vpspasswd -port 22
								;;
							[Nn])
								echo "已取消"
								;;
							*)
								echo "无效的选择，请输入 Y 或 N。"
								;;
						esac
						;;
	
	
					9)
						clear
						install sudo

						# 提示用户输入新用户名
						read -p "请输入新用户名: " new_username

						# 创建新用户并设置密码
						sudo useradd -m -s /bin/bash "$new_username"
						sudo passwd "$new_username"

						# 赋予新用户sudo权限
						echo "$new_username ALL=(ALL:ALL) ALL" | sudo tee -a /etc/sudoers

						# 禁用ROOT用户登录
						sudo passwd -l root

						echo "操作已完成。"
						;;
	
	
					10)
						clear
						ipv6_disabled=$(sysctl -n net.ipv6.conf.all.disable_ipv6)

						echo ""
						if [ "$ipv6_disabled" -eq 1 ]; then
							echo "当前网络优先级设置: IPv4 优先"
						else
							echo "当前网络优先级设置: IPv6 优先"
						fi
						echo "------------------------"

						echo ""
						echo "切换的网络优先级"
						echo "------------------------"
						echo "1. IPv4 优先          2. IPv6 优先"
						echo "------------------------"
						read -p "选择优先的网络: " choice

						case $choice in
							1)
								sysctl -w net.ipv6.conf.all.disable_ipv6=1 > /dev/null 2>&1
								echo "已切换为 IPv4 优先"
								;;
							2)
								sysctl -w net.ipv6.conf.all.disable_ipv6=0 > /dev/null 2>&1
								echo "已切换为 IPv6 优先"
								;;
							*)
								echo "无效的选择"
								;;

						esac
						;;

					11)
						clear
						ss -tulnape
						;;
	
					12)

						if [ "$EUID" -ne 0 ]; then
						  echo "请以 root 权限运行此脚本。"
						  exit 1
						fi

						clear
						# 获取当前交换空间信息
						swap_used=$(free -m | awk 'NR==3{print $3}')
						swap_total=$(free -m | awk 'NR==3{print $2}')

						if [ "$swap_total" -eq 0 ]; then
							swap_percentage=0
						else
							swap_percentage=$((swap_used * 100 / swap_total))
						fi

						swap_info="${swap_used}MB/${swap_total}MB (${swap_percentage}%)"

						echo "当前虚拟内存: $swap_info"

						read -p "是否调整大小?(Y/N): " choice

						case "$choice" in
							[Yy])
								# 输入新的虚拟内存大小
								read -p "请输入虚拟内存大小MB: " new_swap

								# 获取当前系统中所有的 swap 分区
								swap_partitions=$(grep -E '^/dev/' /proc/swaps | awk '{print $1}')

								# 遍历并删除所有的 swap 分区
								for partition in $swap_partitions; do
								  swapoff "$partition"
								  wipefs -a "$partition"  # 清除文件系统标识符
								  mkswap -f "$partition"
								  echo "已删除并重新创建 swap 分区: $partition"
								done

								# 确保 /swapfile 不再被使用
								swapoff /swapfile

								# 删除旧的 /swapfile
								rm -f /swapfile

								# 创建新的 swap 分区
								dd if=/dev/zero of=/swapfile bs=1M count=$new_swap
								chmod 600 /swapfile
								mkswap /swapfile
								swapon /swapfile
								echo "/swapfile swap swap defaults 0 0" >> /etc/fstab

								echo "虚拟内存大小已调整为${new_swap}MB"
								;;
							[Nn])
								echo "已取消"
								;;
							*)
								echo "无效的选择，请输入 Y 或 N。"
								;;
						esac
						;;
	
					13)
						while true; do
							clear
							install sudo
							clear
							# 显示所有用户、用户权限、用户组和是否在sudoers中
							echo "用户列表"
							echo "----------------------------------------------------------------------------"
							printf "%-24s %-34s %-20s %-10s\n" "用户名" "用户权限" "用户组" "sudo权限"
							while IFS=: read -r username _ userid groupid _ _ homedir shell; do
								groups=$(groups "$username" | cut -d : -f 2)
								sudo_status=$(sudo -n -lU "$username" 2>/dev/null | grep -q '(ALL : ALL)' && echo "Yes" || echo "No")
								printf "%-20s %-30s %-20s %-10s\n" "$username" "$homedir" "$groups" "$sudo_status"
							done < /etc/passwd


							echo ""
							echo "账户操作"
							echo "------------------------"
							echo "1. 创建普通账户             2. 创建高级账户"
							echo "------------------------"
							echo "3. 赋予最高权限             4. 取消最高权限"
							echo "------------------------"
							echo "5. 删除账号"
							echo "------------------------"
							echo "0. 返回上一级选单"
							echo "------------------------"
							read -p "请输入你的选择: " sub_choice

							case $sub_choice in
								1)
									# 提示用户输入新用户名
									read -p "请输入新用户名: " new_username

									# 创建新用户并设置密码
									sudo useradd -m -s /bin/bash "$new_username"
									sudo passwd "$new_username"

									echo "操作已完成。"
									;;

								2)
									# 提示用户输入新用户名
									read -p "请输入新用户名: " new_username

									# 创建新用户并设置密码
									sudo useradd -m -s /bin/bash "$new_username"
									sudo passwd "$new_username"

									# 赋予新用户sudo权限
									echo "$new_username ALL=(ALL:ALL) ALL" | sudo tee -a /etc/sudoers

									echo "操作已完成。"

									;;
								3)
									read -p "请输入用户名: " username
									# 赋予新用户sudo权限
									echo "$username ALL=(ALL:ALL) ALL" | sudo tee -a /etc/sudoers
									;;
								4)
									read -p "请输入用户名: " username
									# 从sudoers文件中移除用户的sudo权限
									sudo sed -i "/^$username\sALL=(ALL:ALL)\sALL/d" /etc/sudoers

									;;
								5)
									read -p "请输入要删除的用户名: " username
									# 删除用户及其主目录
									sudo userdel -r "$username"
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
	
					14)
						clear

						echo "随机用户名"
						echo "------------------------"
						for i in {1..5}; do
							username="user$(< /dev/urandom tr -dc _a-z0-9 | head -c6)"
							echo "随机用户名 $i: $username"
						done

						echo ""
						echo "随机姓名"
						echo "------------------------"
						first_names=("John" "Jane" "Michael" "Emily" "David" "Sophia" "William" "Olivia" "James" "Emma" "Ava" "Liam" "Mia" "Noah" "Isabella")
						last_names=("Smith" "Johnson" "Brown" "Davis" "Wilson" "Miller" "Jones" "Garcia" "Martinez" "Williams" "Lee" "Gonzalez" "Rodriguez" "Hernandez")

						# 生成5个随机用户姓名
						for i in {1..5}; do
							first_name_index=$((RANDOM % ${#first_names[@]}))
							last_name_index=$((RANDOM % ${#last_names[@]}))
							user_name="${first_names[$first_name_index]} ${last_names[$last_name_index]}"
							echo "随机用户姓名 $i: $user_name"
						done

						echo ""
						echo "随机UUID"
						echo "------------------------"
						for i in {1..5}; do
							uuid=$(cat /proc/sys/kernel/random/uuid)
							echo "随机UUID $i: $uuid"
						done

						echo ""
						echo "16位随机密码"
						echo "------------------------"
						for i in {1..5}; do
							password=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c16)
							echo "随机密码 $i: $password"
						done

						echo ""
						echo "32位随机密码"
						echo "------------------------"
						for i in {1..5}; do
							password=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32)
							echo "随机密码 $i: $password"
						done
						echo ""

						;;
	
					15)
						while true; do
							clear
							echo "系统时间信息"

							# 获取当前系统时区
							current_timezone=$(timedatectl show --property=Timezone --value)

							# 获取当前系统时间
							current_time=$(date +"%Y-%m-%d %H:%M:%S")

							# 显示时区和时间
							echo "当前系统时区：$current_timezone"
							echo "当前系统时间：$current_time"

							echo ""
							echo "时区切换"
							echo "亚洲------------------------"
							echo "1. 中国上海时间              2. 中国香港时间"
							echo "3. 日本东京时间              4. 韩国首尔时间"
							echo "5. 新加坡时间                6. 印度加尔各答时间"
							echo "7. 阿联酋迪拜时间            8. 澳大利亚悉尼时间"
							echo "欧洲------------------------"
							echo "11. 英国伦敦时间             12. 法国巴黎时间"
							echo "13. 德国柏林时间             14. 俄罗斯莫斯科时间"
							echo "15. 荷兰尤特赖赫特时间       16. 西班牙马德里时间"
							echo "美洲------------------------"
							echo "21. 美国西部时间             22. 美国东部时间"
							echo "23. 加拿大时间               24. 墨西哥时间"
							echo "25. 巴西时间                 26. 阿根廷时间"
							echo "------------------------"
							echo "0. 返回上一级选单"
							echo "------------------------"
							read -p "请输入你的选择: " sub_choice

							case $sub_choice in
								1) timedatectl set-timezone Asia/Shanghai ;;
								2) timedatectl set-timezone Asia/Hong_Kong ;;
								3) timedatectl set-timezone Asia/Tokyo ;;
								4) timedatectl set-timezone Asia/Seoul ;;
								5) timedatectl set-timezone Asia/Singapore ;;
								6) timedatectl set-timezone Asia/Kolkata ;;
								7) timedatectl set-timezone Asia/Dubai ;;
								8) timedatectl set-timezone Australia/Sydney ;;
								11) timedatectl set-timezone Europe/London ;;
								12) timedatectl set-timezone Europe/Paris ;;
								13) timedatectl set-timezone Europe/Berlin ;;
								14) timedatectl set-timezone Europe/Moscow ;;
								15) timedatectl set-timezone Europe/Amsterdam ;;
								16) timedatectl set-timezone Europe/Madrid ;;
								21) timedatectl set-timezone America/Los_Angeles ;;
								22) timedatectl set-timezone America/New_York ;;
								23) timedatectl set-timezone America/Vancouver ;;
								24) timedatectl set-timezone America/Mexico_City ;;
								25) timedatectl set-timezone America/Sao_Paulo ;;
								26) timedatectl set-timezone America/Argentina/Buenos_Aires ;;
								0) break ;; # 跳出循环，退出菜单
								*) break ;; # 跳出循环，退出菜单
							esac
						done
						;;
	
					16)
						if dpkg -l | grep -q 'linux-xanmod'; then
							while true; do
								clear
								kernel_version=$(uname -r)
								echo "您已安装xanmod的BBRv3内核"
								echo "当前内核版本: $kernel_version"

								echo ""
								echo "内核管理"
								echo "------------------------"
								echo "1. 更新BBRv3内核              2. 卸载BBRv3内核"
								echo "------------------------"
								echo "0. 返回上一级选单"
								echo "------------------------"
								read -p "请输入你的选择: " sub_choice

								case $sub_choice in
									1)
										apt update -y
										apt upgrade -y
										echo "XanMod内核已更新。重启后生效"
										reboot

										;;
									2)
										apt purge -y 'linux-*xanmod1*'
										update-grub
										echo "XanMod内核已卸载。重启后生效"
										reboot
										;;
									0)
										break  # 跳出循环，退出菜单
										;;

									*)
										break  # 跳出循环，退出菜单
										;;
								esac
							done
						else

							clear
							echo "请备份数据，将为你升级Linux内核开启BBR3"
							echo "官网介绍: https://xanmod.org/"
							echo "------------------------------------------------"
							echo "仅支持Debian/Ubuntu 仅支持x86_64架构"
							echo "VPS是512M内存的，请提前添加1G虚拟内存，防止因内存不足失联！"
							echo "------------------------------------------------"
							read -p "确定继续吗？(Y/N): " choice

							case "$choice" in
								[Yy])
									if [ -r /etc/os-release ]; then
										. /etc/os-release
										if [ "$ID" != "debian" ] && [ "$ID" != "ubuntu" ]; then
											echo "当前环境不支持，仅支持Debian和Ubuntu系统"
											break
										fi
									else
										echo "无法确定操作系统类型"
										break
									fi

									# 检查系统架构
									arch=$(dpkg --print-architecture)
									if [ "$arch" != "amd64" ]; then
									  echo "当前环境不支持，仅支持x86_64架构"
									  break
									fi

									install wget gnupg

									wget -qO - https://dl.xanmod.org/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg --yes	            

									# 步骤3：添加存储库
									echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | tee /etc/apt/sources.list.d/xanmod-release.list

									version=$(wget -q https://dl.xanmod.org/check_x86-64_psabi.sh && chmod +x check_x86-64_psabi.sh && ./check_x86-64_psabi.sh | grep -oP 'x86-64-v\K\d+|x86-64-v\d+')

									apt update -y
									apt install -y linux-xanmod-x64v$version

									# 步骤5：启用BBR3
									echo "net.core.default_qdisc=fq_pie" > /etc/sysctl.conf; echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
									sysctl -p
									echo "XanMod内核安装并BBR3启用成功。重启后生效"
									rm -f /etc/apt/sources.list.d/xanmod-release.list
									rm -f check_x86-64_psabi.sh*
									reboot

									;;
								[Nn])
									echo "已取消"
									;;
								*)
									echo "无效的选择，请输入 Y 或 N。"
									;;
							esac
						fi
						;;
	
					17)
						if dpkg -l | grep -q iptables-persistent; then
							while true; do
								clear
								echo "防火墙已安装"
								echo "------------------------"
								iptables -L INPUT

								echo ""
								echo "防火墙管理"
								echo "------------------------"
								echo "1. 开放指定端口              2. 关闭指定端口"
								echo "3. 开放所有端口              4. 关闭所有端口"
								echo "------------------------"
								echo "5. IP白名单                  6. IP黑名单"
								echo "7. 清除指定IP"
								echo "------------------------"
								echo "9. 卸载防火墙"
								echo "------------------------"
								echo "0. 返回上一级选单"
								echo "------------------------"
								read -p "请输入你的选择: " sub_choice

								case $sub_choice in
									1)
										read -p "请输入开放的端口号: " o_port
										sed -i "/COMMIT/i -A INPUT -p tcp --dport $o_port -j ACCEPT" /etc/iptables/rules.v4
										sed -i "/COMMIT/i -A INPUT -p udp --dport $o_port -j ACCEPT" /etc/iptables/rules.v4
										iptables-restore < /etc/iptables/rules.v4

										;;
									2)
										read -p "请输入关闭的端口号: " c_port
										sed -i "/--dport $c_port/d" /etc/iptables/rules.v4
										iptables-restore < /etc/iptables/rules.v4
										;;

									3)
										current_port=$(grep -E '^ *Port [0-9]+' /etc/ssh/sshd_config | awk '{print $2}')

										echo -e "*filter\n:INPUT ACCEPT [0:0]\n:FORWARD ACCEPT [0:0]\n:OUTPUT ACCEPT [0:0]\n-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT\n-A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT\n-A INPUT -i lo -j ACCEPT\n-A FORWARD -i lo -j ACCEPT\n-A INPUT -p tcp --dport $current_port -j ACCEPT\nCOMMIT" > /etc/iptables/rules.v4

										iptables-restore < /etc/iptables/rules.v4

										;;
									4)
										current_port=$(grep -E '^ *Port [0-9]+' /etc/ssh/sshd_config | awk '{print $2}')

										echo -e "*filter" > /etc/iptables/rules.v4
										echo -e ":INPUT ACCEPT [0:0]" >> /etc/iptables/rules.v4
										echo -e ":FORWARD ACCEPT [0:0]" >> /etc/iptables/rules.v4
										echo -e ":OUTPUT ACCEPT [0:0]" >> /etc/iptables/rules.v4
										echo -e "-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT" >> /etc/iptables/rules.v4
										echo -e "-A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT" >> /etc/iptables/rules.v4
										echo -e "-A INPUT -i lo -j ACCEPT" >> /etc/iptables/rules.v4
										echo -e "-A FORWARD -i lo -j ACCEPT" >> /etc/iptables/rules.v4
										echo -e "-A INPUT -p tcp --dport $current_port -j ACCEPT" >> /etc/iptables/rules.v4
										echo -e "COMMIT" >> /etc/iptables/rules.v4

										iptables-restore < /etc/iptables/rules.v4

										;;

									5)
										read -p "请输入放行的IP: " o_ip
										sed -i "/COMMIT/i -A INPUT -s $o_ip -j ACCEPT" /etc/iptables/rules.v4
										iptables-restore < /etc/iptables/rules.v4

										;;

									6)
										read -p "请输入封锁的IP: " c_ip
										sed -i "/COMMIT/i -A INPUT -s $c_ip -j DROP" /etc/iptables/rules.v4
										iptables-restore < /etc/iptables/rules.v4
										;;

									7)
										read -p "请输入清除的IP: " d_ip
										sed -i "/-A INPUT -s $d_ip/d" /etc/iptables/rules.v4
										iptables-restore < /etc/iptables/rules.v4
										;;

									9)
										remove iptables-persistent
										rm /etc/iptables/rules.v4
										break
										# echo "防火墙已卸载，重启生效"
										# reboot
										;;

									0)
										break  # 跳出循环，退出菜单
										;;

									*)
										break  # 跳出循环，退出菜单
										;;

								esac
							done
						else

							clear
							echo "将为你安装防火墙，该防火墙仅支持Debian/Ubuntu"
							echo "------------------------------------------------"
							read -p "确定继续吗？(Y/N): " choice

							case "$choice" in
								[Yy])
									if [ -r /etc/os-release ]; then
										. /etc/os-release
										if [ "$ID" != "debian" ] && [ "$ID" != "ubuntu" ]; then
											echo "当前环境不支持，仅支持Debian和Ubuntu系统"
											break
										fi
									else
										echo "无法确定操作系统类型"
										break
									fi

									clear
									iptables_open
									remove iptables-persistent ufw
									rm /etc/iptables/rules.v4

									apt update -y && apt install -y iptables-persistent

									current_port=$(grep -E '^ *Port [0-9]+' /etc/ssh/sshd_config | awk '{print $2}')

									echo -e "*filter" > /etc/iptables/rules.v4
									echo -e ":INPUT DROP [0:0]" >> /etc/iptables/rules.v4
									echo -e ":FORWARD DROP [0:0]" >> /etc/iptables/rules.v4
									echo -e ":OUTPUT ACCEPT [0:0]" >> /etc/iptables/rules.v4
									echo -e "-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT" >> /etc/iptables/rules.v4
									echo -e "-A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT" >> /etc/iptables/rules.v4
									echo -e "-A INPUT -i lo -j ACCEPT" >> /etc/iptables/rules.v4
									echo -e "-A FORWARD -i lo -j ACCEPT" >> /etc/iptables/rules.v4
									echo -e "-A INPUT -p tcp --dport $current_port -j ACCEPT" >> /etc/iptables/rules.v4
									echo -e "COMMIT" >> /etc/iptables/rules.v4


									iptables-restore < /etc/iptables/rules.v4
									systemctl enable netfilter-persistent
									echo "防火墙安装完成"


									;;
								[Nn])
									echo "已取消"
									;;
								*)
									echo "无效的选择，请输入 Y 或 N。"
									;;
							esac
						fi
						;;
	
					18)
						clear
						# 获取当前主机名
						current_hostname=$(hostname)

						echo "当前主机名: $current_hostname"

						# 询问用户是否要更改主机名
						read -p "是否要更改主机名？(y/n): " answer

						if [ "$answer" == "y" ]; then
						  # 获取新的主机名
							read -p "请输入新的主机名: " new_hostname

							# 更改主机名
							if [ -n "$new_hostname" ]; then
								# 根据发行版选择相应的命令
								if [ -f /etc/debian_version ]; then
									# Debian 或 Ubuntu
									hostnamectl set-hostname "$new_hostname"
									sed -i "s/$current_hostname/$new_hostname/g" /etc/hostname
								elif [ -f /etc/redhat-release ]; then
									# CentOS
									hostnamectl set-hostname "$new_hostname"
									sed -i "s/$current_hostname/$new_hostname/g" /etc/hostname
								else
									echo "未知的发行版，无法更改主机名。"
									exit 1
								fi

								# 重启生效
								systemctl restart systemd-hostnamed
								echo "主机名已更改为: $new_hostname"
							else
								echo "无效的主机名。未更改主机名。"
								exit 1
							fi
						else
							echo "未更改主机名。"
						fi

						;;
	
					19)

						# 获取系统信息
						source /etc/os-release

						# 定义 Ubuntu 更新源
						aliyun_ubuntu_source="http://mirrors.aliyun.com/ubuntu/"
						official_ubuntu_source="http://archive.ubuntu.com/ubuntu/"
						initial_ubuntu_source=""

						# 定义 Debian 更新源
						aliyun_debian_source="http://mirrors.aliyun.com/debian/"
						official_debian_source="http://deb.debian.org/debian/"
						initial_debian_source=""

						# 定义 CentOS 更新源
						aliyun_centos_source="http://mirrors.aliyun.com/centos/"
						official_centos_source="http://mirror.centos.org/centos/"
						initial_centos_source=""

						# 获取当前更新源并设置初始源
						case "$ID" in
							ubuntu)
								initial_ubuntu_source=$(grep -E '^deb ' /etc/apt/sources.list | head -n 1 | awk '{print $2}')
								;;
							debian)
								initial_debian_source=$(grep -E '^deb ' /etc/apt/sources.list | head -n 1 | awk '{print $2}')
								;;
							centos)
								initial_centos_source=$(awk -F= '/^baseurl=/ {print $2}' /etc/yum.repos.d/CentOS-Base.repo | head -n 1 | tr -d ' ')
								;;
							*)
								echo "未知系统，无法执行切换源脚本"
								exit 1
								;;
						esac

						# 备份当前源
						backup_sources() {
							case "$ID" in
								ubuntu)
									cp /etc/apt/sources.list /etc/apt/sources.list.bak
									;;
								debian)
									cp /etc/apt/sources.list /etc/apt/sources.list.bak
									;;
								centos)
									if [ ! -f /etc/yum.repos.d/CentOS-Base.repo.bak ]; then
										cp /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
									else
										echo "备份已存在，无需重复备份"
									fi
									;;
								*)
									echo "未知系统，无法执行备份操作"
									exit 1
									;;
							esac
							echo "已备份当前更新源为 /etc/apt/sources.list.bak 或 /etc/yum.repos.d/CentOS-Base.repo.bak"
						}

						# 还原初始更新源
						restore_initial_source() {
							case "$ID" in
								ubuntu)
									cp /etc/apt/sources.list.bak /etc/apt/sources.list
									;;
								debian)
									cp /etc/apt/sources.list.bak /etc/apt/sources.list
									;;
								centos)
									cp /etc/yum.repos.d/CentOS-Base.repo.bak /etc/yum.repos.d/CentOS-Base.repo
									;;
								*)
									echo "未知系统，无法执行还原操作"
									exit 1
									;;
							esac
							echo "已还原初始更新源"
						}

						# 函数：切换更新源
						switch_source() {
							case "$ID" in
								ubuntu)
									sed -i 's|'"$initial_ubuntu_source"'|'"$1"'|g' /etc/apt/sources.list
									;;
								debian)
									sed -i 's|'"$initial_debian_source"'|'"$1"'|g' /etc/apt/sources.list
									;;
								centos)
									sed -i "s|^baseurl=.*$|baseurl=$1|g" /etc/yum.repos.d/CentOS-Base.repo
									;;
								*)
									echo "未知系统，无法执行切换操作"
									exit 1
									;;
							esac
						}

						# 主菜单
						while true; do
							clear
							case "$ID" in
								ubuntu)
									echo "Ubuntu 更新源切换脚本"
									echo "------------------------"
									;;
								debian)
									echo "Debian 更新源切换脚本"
									echo "------------------------"
									;;
								centos)
									echo "CentOS 更新源切换脚本"
									echo "------------------------"
									;;
								*)
									echo "未知系统，无法执行脚本"
									exit 1
									;;
							esac

							echo "1. 切换到阿里云源"
							echo "2. 切换到官方源"
							echo "------------------------"
							echo "3. 备份当前更新源"
							echo "4. 还原初始更新源"
							echo "------------------------"
							echo "0. 返回上一级"
							echo "------------------------"
							read -p "请选择操作: " choice

							case $choice in
								1)
									backup_sources
									case "$ID" in
										ubuntu)
											switch_source $aliyun_ubuntu_source
											;;
										debian)
											switch_source $aliyun_debian_source
											;;
										centos)
											switch_source $aliyun_centos_source
											;;
										*)
											echo "未知系统，无法执行切换操作"
											exit 1
											;;
									esac
									echo "已切换到阿里云源"
									;;
								2)
									backup_sources
									case "$ID" in
										ubuntu)
											switch_source $official_ubuntu_source
											;;
										debian)
											switch_source $official_debian_source
											;;
										centos)
											switch_source $official_centos_source
											;;
										*)
											echo "未知系统，无法执行切换操作"
											exit 1
											;;
									esac
									echo "已切换到官方源"
									;;
								3)
									backup_sources
									case "$ID" in
										ubuntu)
											switch_source $initial_ubuntu_source
											;;
										debian)
											switch_source $initial_debian_source
											;;
										centos)
											switch_source $initial_centos_source
											;;
										*)
											echo "未知系统，无法执行切换操作"
											exit 1
											;;
									esac
									echo "已切换到初始更新源"
									;;
								4)
									restore_initial_source
									;;
								0)
									break
									;;
								*)
									echo "无效的选择，请重新输入"
									;;
							esac
							break_end

						done

						;;
	
					20)

						while true; do
							clear
							echo "定时任务列表"
							crontab -l
							echo ""
							echo "操作"
							echo "------------------------"
							echo "1. 添加定时任务              2. 删除定时任务"
							echo "------------------------"
							echo "0. 返回上一级选单"
							echo "------------------------"
							read -p "请输入你的选择: " sub_choice

							case $sub_choice in
								1)
									read -p "请输入新任务的执行命令: " newquest
									echo "------------------------"
									echo "1. 每周任务                 2. 每天任务"
									read -p "请输入你的选择: " dingshi

									case $dingshi in
										1)
											read -p "选择周几执行任务？ (0-6，0代表星期日): " weekday
											(crontab -l ; echo "0 0 * * $weekday $newquest") | crontab - > /dev/null 2>&1
											;;
										2)
											read -p "选择每天几点执行任务？（小时，0-23）: " hour
											(crontab -l ; echo "0 $hour * * * $newquest") | crontab - > /dev/null 2>&1
											;;
										*)
											break  # 跳出
											;;
									esac
									;;
								2)
									read -p "请输入需要删除任务的关键字: " kquest
									crontab -l | grep -v "$kquest" | crontab -
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
					99)
						clear
						echo "正在重启服务器，即将断开SSH连接"
						reboot
						;;
					0)
						solin

						;;
					*)
						echo "无效的输入!"
						;;
				esac
				break_end
	
			done
            ;;
        00)
            # 脚本更新逻辑
			echo ""
			curl -sS -O https://raw.githubusercontent.com/zxl2008gz/sh/main/solin.sh && chmod +x solin.sh
			echo "脚本已更新到最新版本！"
			break_end
			solin
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
