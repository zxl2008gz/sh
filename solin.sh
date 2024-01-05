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

# 初始化数据库
import_data() {
	dbname=$(echo "$yuming" | sed -e 's/[^A-Za-z0-9]/_/g')
	dbname="${dbname}"
	
	dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
	dbuse=$(grep -oP 'MYSQL_USER:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
	dbusepasswd=$(grep -oP 'MYSQL_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')

	# 设定数据文件的路径，你需要根据实际情况修改此路径
        datafile="/home/web/html/${yuming}/epusdt/upusdt.sql"
	
	# 导入数据
        docker exec -i mysql mysql -u "$dbuse" -p"$dbusepasswd" "$dbname" < "$datafile"
}

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
	 
	 		docker run  -d --name lobe-chat \
			--restart always \
			-p 8089:3210 \
			-e OPENAI_API_KEY=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 \
			-e ACCESS_CODE=860210 \
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

  			docker run --name geminiprochat \
			--restart always \
			-p 3030:3000 \
			-itd \
			-e GEMINI_API_KEY=AIzaSyDL3wR-ncjvgZeJEvX2Yg2WLLbSGEN4bo4 \
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
    			mkdir - /home/web/html/$yuming/vaultwarden

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
    			mkdir - /home/web/html/$yuming/epusdt			
      			chmod 777 -R /home/web/html/$yuming/epusdt
	 
    			dbname=$(echo "$yuming" | sed -e 's/[^A-Za-z0-9]/_/g')
      			dbname="${dbname}"
	 
      			dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
      			dbuse=$(grep -oP 'MYSQL_USER:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
      			dbusepasswd=$(grep -oP 'MYSQL_PASSWORD:\s*\K.*' /home/web/docker-compose.yml | tr -d '[:space:]')
	 		docker exec mysql mysql -u root -p"$dbrootpasswd" -e "CREATE DATABASE $dbname; GRANT ALL PRIVILEGES ON $dbname.* TO \"$dbuse\"@\"%\";"

      			wget -O /home/web/html/$yuming/epusdt/epusdt.sql https://raw.githubusercontent.com/zxl2008gz/docker/main/epusdt/epusdt.sql
			# 设定数据文件的路径，你需要根据实际情况修改此路径
        		datafile="/home/web/html/${yuming}/epusdt/upusdt.sql"
	
			# 导入数据
        		docker exec -i mysql mysql -u "$dbuse" -p"$dbusepasswd" "$dbname" < "$datafile"	 		
 		
    			wget -O /home/web/html/$yuming/epusdt/epusdt.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/epusdt/epusdt.conf
       			sed -i "s/yuming.com/$yuming/g" /home/web/html/$yuming/epusdt/epusdt.conf
	  		sed -i "s/mysql_database=epusdt/mysql_database=$dbname/g" /home/web/html/$yuming/epusdt/epusdt.conf	
			sed -i "s/mysql_user=epusdt/mysql_user=$dbuse/g" /home/web/html/$yuming/epusdt/epusdt.conf	
   			sed -i "s/changeyourpassword/$dbusepasswd/g" /home/web/html/$yuming/epusdt/epusdt.conf	
			read -p "请输入你的tg机器人token: " tg_bot_token
   			sed -i "s/你的tg机器人token/$tg_bot_token/g" /home/web/html/$yuming/epusdt/epusdt.conf
      			read -p "请输入你的tgid: " tg_id
	 		sed -i "s/你的tgid/$tg_id/g" /home/web/html/$yuming/epusdt/epusdt.conf      

			docker run -d \
			--name epusdt \
			--restart=always \
			--network my-network \
			-p 8000:8000 \
			-e mysql_host=mysql \
			-e mysql_database=$dbname \
			-e mysql_user=$dbuse \
			-e mysql_passwd=$dbusepasswd \
			-v /home/web/html/$yuming/epusdt/epusdt.conf:/app/.env \
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
