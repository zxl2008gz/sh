#!/bin/bash

huang='\033[33m'
bai='\033[0m'
lv='\033[0;32m'
lan='\033[0;34m'
hong='\033[31m'
lianglan='\033[96m'
hui='\e[37m'

vers='1.1.0'

set_shortcut_keys(){
    
    # 从 .bashrc 文件中查找已设置的别名
    current_alias=$(grep "alias [^=]*='~/solin.sh'" ~/.bashrc | awk -F"=" '{print $1}' | awk '{print $2}')
    # 如果找到别名，设置 kjjian
    if [ -n "$current_alias" ]; then
        kjjian="$current_alias"
    fi
    # 如果没找到别名，不设置 kjjian，让它使用默认值
}

# 函数：退出
break_end() {
    echo -e "${lv}操作完成${bai}"
    echo "按任意键继续..."
    read -n 1 -s -r -p ""
    echo
    clear
}

# 定义安装软件包函数
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

# 开放所有端口
iptables_open() {
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -F

    ip6tables -P INPUT ACCEPT
    ip6tables -P FORWARD ACCEPT
    ip6tables -P OUTPUT ACCEPT
    ip6tables -F
}

#root用户
root_use() {
    clear
    [ "$EUID" -ne 0 ] && echo -e "${huang}请注意，该功能需要root用户才能运行！${bai}" && break_end && break
}

# 函数：获取匹配特定类型的所有 Docker 容器的名称和关联的镜像信息
get_containers_by_type() {
    local container_type=$1

    # 使用 Docker 命令来获取所有容器及其镜像名和版本信息，然后在 Bash 中过滤
    docker ps --format "{{.Names}}\t{{.Image}}" | awk -v ct="$container_type" '$2 ~ ct {print $1 "\t" $2}'
}

check_port() {
    local port="$1"
    local result=""

    # 按优先级尝试不同的命令
    if command -v ss &>/dev/null; then
        result=$(ss -tuln | grep -q ":$port ")
    elif command -v netstat &>/dev/null; then
        result=$(netstat -tuln | grep -q ":$port ")
    elif command -v lsof &>/dev/null; then
        result=$(lsof -i :"$port" &>/dev/null)
    else
        echo "没有找到可用的端口检测工具(ss/netstat/lsof)"
        return 2
    fi

    if [ -n "$result" ]; then
        # 检查是否是nginx容器占用
        if docker ps --format '{{.Names}}' | grep -q 'nginx'; then
            return 0
        else
            echo -e "${hong}端口 ${huang}$port${hong} 已被占用，无法安装环境，卸载以下程序后重试！${bai}"
            echo "$result"
            return 1
        fi
    fi

    return 0
}

# 安装依赖
install_dependency() {
    clear
    install wget socat unzip tar curl vim
}

# 开启容器的 IPv6 功能，以及限制日志文件大小，防止 Docker 日志塞满硬盘
Limit_log() {
    cat > /etc/docker/daemon.json <<EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "20m",
        "max-file": "3"
    },
    "ipv6": true,
    "fixed-cidr-v6": "fd00:dead:beef:c0::/80",
    "experimental":true,
    "ip6tables":true
}
EOF
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

# 调用函数来安装 Certbot 和设置 cron 任务
install_certbot() {
    if command -v yum &>/dev/null; then
        install epel-release certbot
    elif command -v apt &>/dev/null; then
        install snapd
        snap install core
        snap install --classic certbot
        rm /usr/bin/certbot
        ln -s /snap/bin/certbot /usr/bin/certbot
    else
        install certbot
    fi

    # 切换到一个一致的目录（例如，家目录）
    cd ~ || exit

    # 下载并使脚本可执行
    curl -O https://raw.githubusercontent.com/zxl2008gz/sh/main/auto_cert_renewal.sh
    chmod +x auto_cert_renewal.sh

    # 设置定时任务字符串
    cron_job="0 0 * * * ~/auto_cert_renewal.sh"

    # 检查是否存在相同的定时任务
    existing_cron=$(crontab -l 2>/dev/null | grep -F "$cron_job")

    # 如果不存在，则添加定时任务
    if [ -z "$existing_cron" ]; then
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
        echo "续签任务已添加"
    else
        echo "续签任务已存在，无需添加"
    fi
}

# 函数：获取匹配特定类型的所有 Docker 容器及其镜像名和标签
get_containers_and_images_by_type() {
    local container_type=$1

    echo "Searching for containers with image matching '$container_type'..."

    # 使用 Docker 命令来获取所有容器及其镜像名，然后在 Bash 中过滤
    docker_output=$(docker ps --format "{{.Names}}\t{{.Image}}" | awk -v ct="$container_type" '$2 ~ ct {print $0}')

    # 检查 Docker 命令输出是否为空
    if [ -z "$docker_output" ]; then
        echo "No containers found matching '$container_type'."
    else
        echo "$docker_output"
    fi
}

# 函数：删除匹配特定类型的所有 Docker 容器及其镜像
delete_containers_and_images_by_type() {
    local container_type=$1

    # 获取并列出匹配特定类型的所有 Docker 容器及其镜像
    get_containers_and_images_by_type "$container_type"

    # 提示用户进行删除操作
    if [ -z "$containers" ]; then
        echo "No containers found for type '$container_type'."
        return
    else
        if ask_confirmation "确定所有 $container_type 容器及其镜像？"; then
            # 删除匹配特定类型的所有 Docker 容器及其镜像
            docker rm -f $(docker ps -aq --filter "ancestor=$container_type") >/dev/null 2>&1
            docker rmi $(docker images "$container_type" -q) >/dev/null 2>&1
            echo "Containers and images of type '$container_type' removed successfully."
        else
            echo "操作已取消。"
        fi
    fi    
}

# SSL自签名
default_server_ssl() {
    install openssl
    # openssl req -x509 -nodes -newkey rsa:2048 -keyout /home/web/certs/default_server.key -out /home/web/certs/default_server.crt -days 5475 -subj "/C=US/ST=State/L=City/O=Organization/OU=Organizational Unit/CN=Common Name"

    if command -v dnf &>/dev/null || command -v yum &>/dev/null; then
        openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -keyout /home/docker/web/certs/default_server.key -out /home/docker/web/certs/default_server.crt -days 5475 -subj "/C=US/ST=State/L=City/O=Organization/OU=Organizational Unit/CN=Common Name"
    else
        openssl genpkey -algorithm Ed25519 -out /home/docker/web/certs/default_server.key
        openssl req -x509 -key /home/docker/web/certs/default_server.key -out /home/docker/web/certs/default_server.crt -days 5475 -subj "/C=US/ST=State/L=City/O=Organization/OU=Organizational Unit/CN=Common Name"
    fi
}

# 函数：获取用户输入或默认数据，20秒后无输入则使用默认值，如果开始输入则等待完成
get_default_data() {
    local prompt="$1"
    local default_value="$2"
    local timeout="$3"
    local input=""
    local partial_input=""
    
    # 首次尝试读取输入，20秒超时
    read -t $timeout -p "$prompt (默认为：$default_value): " input || partial_input="$input"

    # 检查是否有部分输入
    if [ -n "$partial_input" ]; then
        # 如果有部分输入，继续读取直到完成
        input="$partial_input"
        while IFS= read -r -n1 -s char; do
            # 读取单个字符，没有超时
            input+="$char"
            # 检查是否是结束字符（回车）
            if [[ "$char" == $'\n' ]]; then
                break
            fi
        done
        # 从输入中移除最后的换行符
        input="${input%$'\n'}"
    elif [ -z "$input" ]; then
        # 超时无输入，使用默认值
        input="$default_value"
    fi

    echo "$input"
}

# nginx配置
nginx_config() {
    nginx_path=$(get_default_data "请输入nginx的路径" "/home/docker" "20") 
    # 创建必要的目录和文件
    if [ -z "$nginx_path" ]; then
        echo "Error: nginx_path is not set."
        exit 1
    fi

    mkdir -p "$nginx_path" && cd "$nginx_path" && \
    mkdir -p html web/certs web/conf.d web/log/nginx && \
    touch docker-compose-nginx.yml

    nginx_container_name=$(get_default_data "请输入nginx的容器名" "nginx" "20") 
    nginx_container_image=$(get_default_data "请输入nginx的镜像名" "nginx:alpine" "20")

    # 下载 docker-compose.yml 文件并进行替换
    wget -O $nginx_path/web/nginx.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/LDNMP/nginx.conf
    wget -O $nginx_path/web/conf.d/default.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/LDNMP/default.conf

    default_server_ssl
    delete_containers_and_images_by_type "nginx"

    wget -O $nginx_path/docker-compose-nginx.yml https://raw.githubusercontent.com/zxl2008gz/docker/main/LDNMP/docker-compose-nginx.yml
    # 在 docker-compose.yml 文件中进行替换
    sed -i "s|container_name: nginx|container_name: ${nginx_container_name}|g" $nginx_path/docker-compose-nginx.yml
    sed -i "s|image: nginx:alpine|image: ${nginx_container_image}|g" $nginx_path/docker-compose-nginx.yml
    sed -i "s|- ./|- ${nginx_path}/|g" $nginx_path/docker-compose-nginx.yml
}

# 安装 nginx
install_nginx() {
    nginx_config
    cd $nginx_path && docker-compose -f docker-compose-nginx.yml up -d
}

# 定义显示 nginx 版本的函数
nginx_display() {
    local container_type=$1

    # 调用函数并存储输出
    container_info=$(get_containers_by_type "$container_type")

    # 解析容器名称和镜像信息
    container_name=$(echo "$container_info" | awk '{print $1}')
    container_image=$(echo "$container_info" | awk '{print $2}')
    if [ -z "$container_name" ]; then
        echo "No container found matching '$container_type'."
        return
    fi

    # 如果你需要执行 nginx -v 命令来获取版本信息，可以这样做：
    nginx_version_output=$(docker exec "$container_name" nginx -v 2>&1)
    nginx_version=$(echo "$nginx_version_output" | grep -oP 'nginx/\K[0-9]+\.[0-9]+\.[0-9]+')

    if [ -z "$nginx_version" ]; then
        echo "Failed to retrieve nginx version."
    else
        echo "nginx已安装完成"
        echo "当前版本: v$nginx_version"
    fi
}

# 安装更新MYSQL环境
mysql_config() {
    db_mysql_path=$(get_default_data "请输入MYSQL的路径" "/home/docker" "20") 
    # 创建必要的目录和文件
    if [ -z "$db_mysql_path" ]; then
        echo "Error: db_mysql_path is not set."
        exit 1
    fi

    mkdir -p "$db_mysql_path" && cd "$db_mysql_path" && \
    mkdir -p mysql mysql_backup && \
    touch docker-compose-mysql.yml

    mysql_container_name=$(get_default_data "请输入MYSQL的容器名" "mysql" "20") 
    mysql_container_image=$(get_default_data "请输入MYSQL的镜像名" "mysql" "20")
    mysql_container_volume=$(get_default_data "请输入持久化volume路径" "./mysql" "20")

    mysql_container_rootwd=$(get_default_data "请设置MYSQL的容器的root密码" "mysqlwebroot" "20") 
    mysql_container_dbuse=$(get_default_data "请设置MYSQL的容器的用户名" "mysqluse" "20")
    mysql_container_passwd=$(get_default_data "请设置MYSQL的容器的用户密码" "mysqlpasswd" "20")

    install openssl

    # 判断是否使用了默认密码，并在是的情况下生成新的随机密码
    if [[ "$mysql_container_rootwd" == "mysqlwebroot" ]]; then
        echo "使用默认root密码，正在生成新的随机密码..."
        mysql_container_rootwd=$(openssl rand -base64 16)
        echo "新的root密码：$mysql_container_rootwd"
    fi

    if [[ "$mysql_container_dbuse" == "mysqluse" ]]; then
        echo "使用默认用户名，正在生成新的随机用户名..."
        mysql_container_dbuse=$(openssl rand -hex 4)
        echo "新的用户名：$mysql_container_dbuse"
    fi

    if [[ "$mysql_container_passwd" == "mysqlpasswd" ]]; then
        echo "使用默认用户密码，正在生成新的随机密码..."
        mysql_container_passwd=$(openssl rand -base64 8)
        echo "新的用户密码：$mysql_container_passwd"
    fi

    # 下载 docker-compose.yml 文件并进行替换
    wget -O $db_mysql_path/docker-compose-mysql.yml https://raw.githubusercontent.com/zxl2008gz/docker/main/LDNMP/docker-compose-mysql.yml

    # 在 docker-compose.yml 文件中进行替换
    sed -i "s|mysqlwebroot|$mysql_container_rootwd|g" $db_mysql_path/docker-compose-mysql.yml
    sed -i "s|mysqlpasswd|$mysql_container_passwd|g" $db_mysql_path/docker-compose-mysql.yml
    sed -i "s|mysqluse|$mysql_container_dbuse|g" $db_mysql_path/docker-compose-mysql.yml
}

# php配置文件
php_config() {
    php_path=$(get_default_data "请输入php的路径" "/home/docker" "20") 
    # 创建必要的目录和文件
    if [ -z "$php_path" ]; then
        echo "Error: php_path is not set."
        exit 1
    fi

    mkdir -p "$php_path" && cd "$php_path" && \
    mkdir -p html && \
    touch docker-compose-php-php74.yml

    php_container_name=$(get_default_data "请输入php的容器名" "php" "20") 
    php_container_image=$(get_default_data "请输入php的镜像名" "php:fpm-alpine" "20")

    php74_container_name=$(get_default_data "请输入php的容器名" "php74" "20") 
    php74_container_image=$(get_default_data "请输入php的镜像名" "php:7.4-fpm-alpine" "20")
    
    wget -O $php_path/docker-compose-php-php74.yml https://raw.githubusercontent.com/zxl2008gz/docker/main/LDNMP/docker-compose-php-php74.yml

    #在 docker-compose.yml 文件中进行替换
    sed -i "s|container_name: php|container_name: ${php_container_name}|g" $php_path/docker-compose-php-php74.yml
    sed -i "s|image: php:fpm-alpine|image: ${php_container_image}|g" $php_path/docker-compose-php-php74.yml

    sed -i "s|container_name: php74|container_name: ${php74_container_name}|g" $php_path/docker-compose-php-php74.yml
    sed -i "s|image: php:7.4-fpm-alpine|image: ${php74_container_image}|g" $php_path/docker-compose-php-php74.yml
    sed -i "s|- ./|- ${php_path}/|g" $php_path/docker-compose-php-php74.yml

    php_is_exit=$(get_default_data "是否需要安装其他版本的php？(默认为不安装，需要安装请输入Y)" "n" "20") 

    # 转换用户输入为小写，以便忽略大小写进行比较
    php_is_exit=$(echo "$php_is_exit" | tr '[:upper:]' '[:lower:]')

    # 判断用户输入
    if [ "$php_is_exit" == "y" ]; then
        echo "用户选择安装其他版本的 PHP。"
        php_container_name=$(get_default_data "请输入php的容器名" "php" "20") 
        php_container_image=$(get_default_data "请输入php的镜像名" "php:fpm-alpine" "20")
        # 下载 docker-compose.yml 文件并进行替换
        wget -O $php_path/docker-compose-php.yml https://raw.githubusercontent.com/zxl2008gz/docker/main/LDNMP/docker-compose-php.yml

        # 在 docker-compose.yml 文件中进行替换
        sed -i "s|container_name: php|container_name: ${php_container_name}|g" $php_path/docker-compose-php.yml
        sed -i "s|image: php:fpm-alpine|image: ${php_container_image}|g" $php_path/docker-compose-php.yml
        sed -i "s|- ./|- ${php_path}/|g" $php_path/docker-compose-php.yml

        echo "" >> /home/docker/docker-compose-php.yml

        # 追加经过筛选的内容（除去第一行）
        sed -n '/services:/,$p' /home/docker/docker-compose-php.yml | sed '1d' >> /home/docker/docker-compose-php-php74.yml
    elif [ "$php_is_exit" == "n" ]; then
        echo "用户选择不安装其他版本的 PHP。"
    else
        echo "无效的输入。默认选择不安装 PHP。"
    fi    
}

# 安装php/php74
install_php_php74() {
    php_config
    cd $php_path && docker-compose -f docker-compose-php-php74.yml up -d
}

# redis配置文件
redis_config() {
    redis_path=$(get_default_data "请输入redis的路径" "/home/docker" "20") 
    # 创建必要的目录和文件
    if [ -z "$redis_path" ]; then
        echo "Error: redis_path is not set."
        exit 1
    fi

    mkdir -p "$redis_path" && cd "$redis_path" && \
    mkdir -p redis && \
    touch docker-compose-redis.yml

    redis_container_name=$(get_default_data "请输入redis的容器名" "redis" "20") 
    redis_container_image=$(get_default_data "请输入redis的镜像名" "redis:alpine" "20")

    # 下载 docker-compose.yml 文件并进行替换
    wget -O $redis_path/docker-compose-redis.yml https://raw.githubusercontent.com/zxl2008gz/docker/main/LDNMP/docker-compose-redis.yml

    # 在 docker-compose.yml 文件中进行替换
    sed -i "s|container_name: redis|container_name: ${redis_container_name}|g" $redis_path/docker-compose-redis.yml
    sed -i "s|image: redis:alpine|image: ${redis_container_image}|g" $redis_path/docker-compose-redis.yml
    sed -i "s|- ./|- ${redis_path}/|g" $redis_path/docker-compose-redis.yml
}

# 安装redis
install_redis() {
    redis_config
    cd $redis_path && docker-compose -f docker-compose-redis.yml up -d
}

# ldnmp配置文件
create_ldnmp_file() {
    nginx_config
    mysql_config
    php_config
    redis_config
    echo "" >> /home/docker/docker-compose-nginx.yml
    echo "" >> /home/docker/docker-compose-mysql.yml
    echo "" >> /home/docker/docker-compose-php-php74.yml
    echo "" >> /home/docker/docker-compose-redis.yml
    # 目标文件路径
    target_file="/home/docker/docker-compose.yml"

    # 检查文件是否存在
    if [ -f "$target_file" ]; then
        # 文件存在，清空内容
        cp $target_file $target_file.bak
        rm "$target_file"
        echo "文件 $target_file 已清空。"
    else
        # 文件不存在，输出提示
        echo "文件 $target_file 不存在，无法清空。"
    fi
    touch /home/docker/docker-compose.yml
    echo "" >> /home/docker/docker-compose.yml
    echo "services:" >> /home/docker/docker-compose.yml
    # 追加经过筛选的内容（除去第一行和包含'version:'的行）
    sed -n '/services:/,$p' /home/docker/docker-compose-nginx.yml | sed '1d' | sed '/version:/d' >> /home/docker/docker-compose.yml
    sed -n '/services:/,$p' /home/docker/docker-compose-mysql.yml | sed '1d' | sed '/version:/d' >> /home/docker/docker-compose.yml
    sed -n '/services:/,$p' /home/docker/docker-compose-php-php74.yml | sed '1d' | sed '/version:/d' >> /home/docker/docker-compose.yml
    sed -n '/services:/,$p' /home/docker/docker-compose-redis.yml | sed '1d' | sed '/version:/d' >> /home/docker/docker-compose.yml

    cd /home/docker && docker-compose -f docker-compose.yml up -d
}

# 安装mysql-redis-php
install_mysql_redis_php(){
    mysql_config
    php_config
    redis_config
    echo "" >> /home/docker/docker-compose-mysql.yml
    echo "" >> /home/docker/docker-compose-php-php74.yml
    echo "" >> /home/docker/docker-compose-redis.yml
    # 目标文件路径
    target_file="/home/docker/docker-compose-mysql-php-redis.yml"
    # 检查文件是否存在
    if [ -f "$target_file" ]; then
        # 文件存在，清空内容
        cp $target_file $target_file.bak
        rm "$target_file"
        echo "文件 $target_file 已清空。"
    else
        # 文件不存在，输出提示
        echo "文件 $target_file 不存在，无法清空。"
    fi
    touch /home/docker/docker-compose-mysql-php-redis.yml
    echo "" >> /home/docker/docker-compose-mysql-php-redis.yml
    echo "services:" >> /home/docker/docker-compose-mysql-php-redis.yml
    # 追加经过筛选的内容（除去第一行和包含'version:'的行）
    sed -n '/services:/,$p' /home/docker/docker-compose-mysql.yml | sed '1d' | sed '/version:/d' >> /home/docker/docker-compose-mysql-php-redis.yml
    sed -n '/services:/,$p' /home/docker/docker-compose-php-php74.yml | sed '1d' | sed '/version:/d' >> /home/docker/docker-compose-mysql-php-redis.yml
    sed -n '/services:/,$p' /home/docker/docker-compose-redis.yml | sed '1d' | sed '/version:/d' >> /home/docker/docker-compose-mysql-php-redis.yml

    cd /home/docker && docker-compose -f docker-compose-mysql-php-redis.yml up -d
}

# 重新启动自定义app
restart_customize_app() {
    local customize_app_version=$1

    docker exec $customize_app_version chmod -R 777 /var/www/html
    docker restart $customize_app_version > /dev/null 2>&1
}

# 配置LDNMP环境
install_php() {
    
    # 定义要执行的命令
    commands=(

        "docker exec php apt update > /dev/null 2>&1"
        "docker exec php apk update > /dev/null 2>&1"
        "docker exec php74 apt update > /dev/null 2>&1"
        "docker exec php74 apk update > /dev/null 2>&1"

        # php安装包管理
        "curl -sL https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions -o /usr/local/bin/install-php-extensions > /dev/null 2>&1"
        "docker exec php mkdir -p /usr/local/bin/ > /dev/null 2>&1"
        "docker exec php74 mkdir -p /usr/local/bin/ > /dev/null 2>&1"
        "docker cp /usr/local/bin/install-php-extensions php:/usr/local/bin/ > /dev/null 2>&1"
        "docker cp /usr/local/bin/install-php-extensions php74:/usr/local/bin/ > /dev/null 2>&1"
        "docker exec php chmod +x /usr/local/bin/install-php-extensions > /dev/null 2>&1"
        "docker exec php74 chmod +x /usr/local/bin/install-php-extensions > /dev/null 2>&1"

        # php安装扩展
        "docker exec php install-php-extensions mysqli > /dev/null 2>&1"
        "docker exec php install-php-extensions pdo_mysql > /dev/null 2>&1"
        "docker exec php install-php-extensions gd intl zip > /dev/null 2>&1"
        "docker exec php install-php-extensions exif > /dev/null 2>&1"
        "docker exec php install-php-extensions bcmath > /dev/null 2>&1"
        "docker exec php install-php-extensions opcache > /dev/null 2>&1"
        "docker exec php install-php-extensions imagick redis > /dev/null 2>&1"

        # php配置参数
        "docker exec php sh -c 'echo \"upload_max_filesize=50M \" > /usr/local/etc/php/conf.d/uploads.ini' > /dev/null 2>&1"
        "docker exec php sh -c 'echo \"post_max_size=50M \" > /usr/local/etc/php/conf.d/post.ini' > /dev/null 2>&1"
        "docker exec php sh -c 'echo \"memory_limit=256M\" > /usr/local/etc/php/conf.d/memory.ini' > /dev/null 2>&1"
        "docker exec php sh -c 'echo \"max_execution_time=1200\" > /usr/local/etc/php/conf.d/max_execution_time.ini' > /dev/null 2>&1"
        "docker exec php sh -c 'echo \"max_input_time=600\" > /usr/local/etc/php/conf.d/max_input_time.ini' > /dev/null 2>&1"

        # php重启
        "docker exec php chmod -R 777 /var/www/html"
        "docker restart php > /dev/null 2>&1"

        # php7.4安装扩展
        "docker exec php74 install-php-extensions mysqli > /dev/null 2>&1"
        "docker exec php74 install-php-extensions pdo_mysql > /dev/null 2>&1"
        "docker exec php74 install-php-extensions gd intl zip > /dev/null 2>&1"
        "docker exec php74 install-php-extensions exif > /dev/null 2>&1"
        "docker exec php74 install-php-extensions bcmath > /dev/null 2>&1"
        "docker exec php74 install-php-extensions opcache > /dev/null 2>&1"
        "docker exec php74 install-php-extensions imagick redis > /dev/null 2>&1"

        # php7.4配置参数
        "docker exec php74 sh -c 'echo \"upload_max_filesize=50M \" > /usr/local/etc/php/conf.d/uploads.ini' > /dev/null 2>&1"
        "docker exec php74 sh -c 'echo \"post_max_size=50M \" > /usr/local/etc/php/conf.d/post.ini' > /dev/null 2>&1"
        "docker exec php74 sh -c 'echo \"memory_limit=256M\" > /usr/local/etc/php/conf.d/memory.ini' > /dev/null 2>&1"
        "docker exec php74 sh -c 'echo \"max_execution_time=1200\" > /usr/local/etc/php/conf.d/max_execution_time.ini' > /dev/null 2>&1"
        "docker exec php74 sh -c 'echo \"max_input_time=600\" > /usr/local/etc/php/conf.d/max_input_time.ini' > /dev/null 2>&1"

        # php7.4重启
        "docker exec php74 chmod -R 777 /var/www/html"
        "docker restart php74 > /dev/null 2>&1"
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

# 获取ldnmp的信息
ldnmp_info() {
    # 获取nginx版本
    nginx_version=$(docker exec nginx nginx -v 2>&1)
    nginx_version=$(echo "$nginx_version" | grep -oP "nginx/\K[0-9]+\.[0-9]+\.[0-9]+")
    echo -n "nginx : v$nginx_version"

    # 获取mysql版本
    dbrootpasswd=$(docker exec mysql bash -c 'echo "$MYSQL_ROOT_PASSWORD"' 2>/dev/null)
    mysql_version=$(docker exec mysql mysql -u root -p"$dbrootpasswd" -e "SELECT VERSION();" 2>/dev/null | tail -n 1)
    echo -n "            mysql : v$mysql_version"

    # 获取php版本
    php_version=$(docker exec php php -r "echo PHP_VERSION;" 2>/dev/null)
    echo -n "            php : v$php_version"

    # 获取redis版本
    redis_version=$(docker exec redis redis-server -v 2>&1 | grep -oP "v=+\K[0-9]+\.[0-9]+")
    echo "            redis : v$redis_version"

    echo "------------------------"
    echo ""
}

# 获取mysql-php-redis的信息
mysql_php_redis_info() {

    # 获取mysql版本
    dbrootpasswd=$(docker exec mysql bash -c 'echo "$MYSQL_ROOT_PASSWORD"' 2>/dev/null)
    mysql_version=$(docker exec mysql mysql -u root -p"$dbrootpasswd" -e "SELECT VERSION();" 2>/dev/null | tail -n 1)
    echo -n "            mysql : v$mysql_version"

    # 获取php版本
    php_version=$(docker exec php php -r "echo PHP_VERSION;" 2>/dev/null)
    echo -n "            php : v$php_version"

    # 获取redis版本
    redis_version=$(docker exec redis redis-server -v 2>&1 | grep -oP "v=+\K[0-9]+\.[0-9]+")
    echo "            redis : v$redis_version"

    echo "------------------------"
    echo ""
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

ldnmp_install_status_one() {

    if docker inspect "php" &>/dev/null; then
        echo -e "${huang}LDNMP环境已安装。无法再次安装。可以使用37. 更新LDNMP环境${bai}"
        break_end
        break
    else
        echo
    fi

}

# ldnmp安装状态
ldnmp_install_status() {
    if ! docker inspect "php" &>/dev/null; then
        echo -e "${huang}LDNMP环境未安装，请先安装LDNMP环境，再部署网站${bai}"
        break_end
        return 1
    fi
    
    echo "LDNMP环境已安装，开始部署 $webname"
    return 0
}

#nginx状态
nginx_install_status() {
    if ! docker inspect "nginx" &>/dev/null; then
        echo -e "${huang}nginx未安装，请先安装nginx环境，再部署网站${bai}"
        break_end
        return 1
    fi

    echo "nginx环境已安装，开始部署 $webname"
    return 0
}

#检测域名正确性
repeat_add_yuming() {
    local domain_regex="^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$"
    
    if [[ ! $yuming =~ $domain_regex ]]; then
        echo "域名格式不正确，请重新输入"
        return 1
    fi

    if [ -e "/home/docker/web/conf.d/$yuming.conf" ]; then
        echo -e "${huang}当前 ${yuming} 域名已被使用，请前往31站点管理，删除站点，再部署 ${webname} ！${bai}"
        return 1
    fi

    echo "当前 ${yuming} 域名可用"
    return 0
}

#添加域名
add_yuming() {
      read ipv4_address ipv6_address < <(get_ip_address)
      echo -e "先将域名解析到本机IP: ${huang}$ipv4_address  $ipv6_address${bai}"
      read -p "请输入你解析的域名: " yuming
      repeat_add_yuming
}

# 获取SSL
install_ssltls() {
      docker stop nginx > /dev/null 2>&1
      iptables_open
      cd ~
      certbot certonly --standalone -d $yuming --email your@email.com --agree-tos --no-eff-email --force-renewal --key-type ecdsa
      cp /etc/letsencrypt/live/$yuming/fullchain.pem /home/docker/web/certs/${yuming}_cert.pem
      cp /etc/letsencrypt/live/$yuming/privkey.pem /home/docker/web/certs/${yuming}_key.pem
      docker start nginx > /dev/null 2>&1
}


# 站点重定向配置
redirect_config() {

    wget -O /home/docker/web/conf.d/$yuming.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/redirect
    sed -i "s/yuming.com/$yuming/g" /home/docker/web/conf.d/$yuming.conf
    sed -i "s/baidu.com/$reverseproxy/g" /home/docker/web/conf.d/$yuming.conf

    docker restart nginx

    clear
    echo "您的重定向网站做好了！"
    echo "https://$yuming"
}

# 获取数据库容器的名称
get_db_container_name() {
    local db_image_keyword="$1"
    docker ps --format "{{.Names}}\t{{.Image}}" | grep "$db_image_keyword" | awk '{print $1}'
}

# 获取数据库配置值
get_config_value() {
    local var_name="$1"
    local container_name="$2"
    docker exec "$container_name" /bin/sh -c "echo \${$var_name}"
}

# 函数：获取数据库凭据
get_db_credentials() {
    local container_name=$1
    declare -A credentials

    # 使用内置的 get_config_value 函数来获取环境变量
    credentials[user]=$(get_config_value 'MYSQL_USER' "$container_name")
    credentials[password]=$(get_config_value 'MYSQL_PASSWORD' "$container_name")
    credentials[root_password]=$(get_config_value 'MYSQL_ROOT_PASSWORD' "$container_name")

    # 返回关联数组
    echo "${credentials[user]} ${credentials[password]} ${credentials[root_password]}"
}

# 添加wordpress 配置
wordpress_config() {
    wget -O /home/docker/web/conf.d/$yuming.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/wordpress/wordpress.com.conf
    sed -i "s/yuming.com/$yuming/g" /home/docker/web/conf.d/$yuming.conf

    cd /home/docker/html
    mkdir $yuming
    cd $yuming
    wget -O latest.zip https://cn.wordpress.org/latest-zh_CN.zip
    unzip latest.zip
    rm latest.zip

    echo "define('FS_METHOD', 'direct'); define('WP_REDIS_HOST', 'redis'); define('WP_REDIS_PORT', '6379');" >> /home/docker/html/$yuming/wordpress/wp-config-sample.php
}

# wordpress 显示
wordpress_display() {
    local container_name1="$1"
    local container_name_mysql=$(get_db_container_name "$container_name1")
    local credentials=($(get_db_credentials "$container_name_mysql"))
    clear
    echo "您的${webname}搭建好了！"
    echo "https://$yuming"
    echo "------------------------"
    echo "WP安装信息如下: "
    echo "数据库名: $dbname"
    echo "用户名: ${credentials[0]}"
    echo "密码: ${credentials[1]}"
    echo "数据库地址: mysql"
    echo "表前缀: wp_"
}

# 函数：获取指定仓库的最新版本
get_latest_version() {
    local repo_url="$1"  # GitHub 仓库的 API URL 作为参数传入

    # 使用curl从GitHub API获取数据
    latest_version=$(curl -s $repo_url | grep '"tag_name"' | cut -d '"' -f4)
    
    if [[ -z "$latest_version" ]]; then
        echo "获取最新版本失败。"
        exit 1
    else
        echo $latest_version
    fi
}

# 添加kodbox 配置
kodbox_config() {
    wget -O /home/docker/web/conf.d/$yuming.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/kodbox/kodbox.com.conf
    sed -i "s/yuming.com/$yuming/g" /home/docker/web/conf.d/$yuming.conf

    cd /home/docker/html
    mkdir $yuming
    cd $yuming

    # 获取最新版本的 tag 名称
    # 设置 GitHub 仓库的 API URL
    repo_url="https://api.github.com/repos/kalcaddle/kodbox/releases/latest"

    # 调用函数，获取最新版本
    latest_version=$(get_latest_version $repo_url)

    sed -i "s/kodbox-1.49.10/kodbox-$latest_version/g" /home/docker/web/conf.d/$yuming.conf

    # 构建下载链接并下载最新版本
    download_url="https://github.com/kalcaddle/kodbox/archive/refs/tags/$latest_version.zip"
    wget -O "$latest_version.zip" "$download_url"

    # 解压并清理
    unzip -o "$latest_version.zip"
    rm "$latest_version.zip"
}

# wordpress 显示
kodbox_display() {
    local container_name1="$1"
    local container_name_mysql=$(get_db_container_name "$container_name1")
    local credentials=($(get_db_credentials "$container_name_mysql"))
    clear
    echo "您的${webname}搭建好了！"
    echo "https://$yuming"
    echo "------------------------"
    echo "${webname}安装信息如下: "
    echo "数据库名: $dbname"
    echo "用户名: ${credentials[0]}"
    echo "密码: ${credentials[1]}"
    echo "数据库地址: mysql"
    echo "redis主机: redis"
}

# 添加dujiaoka 配置
dujiaoka_config() {

    wget -O /home/docker/web/conf.d/$yuming.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/dujiaoka/dujiaoka.com.conf

    sed -i "s/yuming.com/$yuming/g" /home/docker/web/conf.d/$yuming.conf

    cd /home/docker/html
    mkdir $yuming
    cd $yuming

    install inotify-tools
    # 获取最新版本的 tag 名称
    # 设置 GitHub 仓库的 API URL
    repo_url="https://api.github.com/repos/assimon/dujiaoka/releases/latest"
    
    # 调用函数，获取最新版本
    latest_version=$(get_latest_version $repo_url)

    # 构造下载链接并下载最新版本
    echo "正在下载 $latest_version..."
    wget "https://github.com/assimon/dujiaoka/releases/download/$latest_version/$latest_version-antibody.tar.gz" -O dujiaoka-latest.tar.gz

    # 解压并清理压缩包
    tar -zxvf dujiaoka-latest.tar.gz
    rm dujiaoka-latest.tar.gz
}

# dujiaoka 显示
dujiaoka_display() {
    clear
    local container_name1="$1"
    local container_name_mysql=$(get_db_container_name "$container_name1")
    local credentials=($(get_db_credentials "$container_name_mysql"))
    echo "您的${webname}网站搭建好了！"
    echo "https://$yuming"
    echo "------------------------"
    echo "安装信息如下: "
    echo "数据库地址: mysql"
    echo "数据库端口: 3306"
    echo "数据库名: $dbname"
    echo "用户名: ${credentials[0]}"
    echo "密码:${credentials[1]}"
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
    echo "登录时右上角如果出现红色error0请使用如下命令: "
    echo "我也很气愤独角数卡为啥这么麻烦，会有这样的问题！"
    echo "sed -i 's/ADMIN_HTTPS=false/ADMIN_HTTPS=true/g' /home/docker/web/html/$yuming/dujiaoka/.env"
}

# 添加flarum 配置
flarum_config() {

    wget -O /home/docker/web/conf.d/$yuming.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/flarum/flarum.com.conf

    sed -i "s/yuming.com/$yuming/g" /home/docker/web/conf.d/$yuming.conf

    cd /home/docker/html
    mkdir $yuming
    cd $yuming

    # 设置变量
    container_name="php"  # 假设使用的容器名为"php"
    domain="$yuming"      # 确保这个变量已经正确设置

    # 安装 Composer
    docker exec $container_name sh -c "php -r \"copy('https://getcomposer.org/installer', 'composer-setup.php');\""
    docker exec $container_name sh -c "php composer-setup.php"
    docker exec $container_name sh -c "php -r \"unlink('composer-setup.php');\""
    docker exec $container_name sh -c "mv composer.phar /usr/local/bin/composer"

    # 检查 Composer 是否安装成功
    docker exec $container_name composer --version

    # 使用 Composer 创建 Flarum 项目
    docker exec $container_name composer create-project flarum/flarum /var/www/html/$domain

    # 安装 Flarum 中文简体语言包
    docker exec $container_name sh -c "cd /var/www/html/$domain && composer require flarum-lang/chinese-simplified"

    # 安装 Flarum 投票插件
    docker exec $container_name sh -c "cd /var/www/html/$domain && composer require fof/polls"
}

# flarum 显示
flarum_display() {
    clear
    local container_name1="$1"
    local container_name_mysql=$(get_db_container_name "$container_name1")
    local credentials=($(get_db_credentials "$container_name_mysql"))
    echo "您的${webname}网站搭建好了！"
    echo "https://$yuming"
    echo "------------------------"
    echo "安装信息如下: "
    echo "数据库地址: mysql"
    echo "数据库名: $dbname"
    echo "用户名: ${credentials[0]}"
    echo "密码: ${credentials[1]}"
    echo "表前缀: flarum_"
    echo "管理员信息自行设置"
}

# 域名路径
yuming_path() {
    cd /home/docker/html
    mkdir -p /home/docker/html/$yuming
    cd /home/docker/html/$yuming
}


# 重启LDNMP
restart_ldnmp() {
    
    restart_customize_app "nginx"
    restart_customize_app "php"
    restart_customize_app "php74"
}

# nginx的状态
nginx_status() {

    sleep 1

    nginx_container_name="nginx"

    container_name_mysql=$1

    # 获取容器的状态
    container_status=$(docker inspect -f '{{.State.Status}}' "$nginx_container_name" 2>/dev/null)

    # 获取容器的重启状态
    container_restart_count=$(docker inspect -f '{{.RestartCount}}' "$nginx_container_name" 2>/dev/null)

    # 检查容器是否在运行，并且没有处于"Restarting"状态
    if [ "$container_status" == "running" ]; then
        echo ""
    else
        rm -r /home/docker/html/$yuming >/dev/null 2>&1
        rm /home/docker/web/conf.d/$yuming.conf >/dev/null 2>&1
        rm /home/docker/web/certs/${yuming}_key.pem >/dev/null 2>&1
        rm /home/docker/web/certs/${yuming}_cert.pem >/dev/null 2>&1
        docker restart nginx >/dev/null 2>&1

        # Get the MySQL root password from the environment variable
        dbrootpasswd=$(get_config_value 'MYSQL_ROOT_PASSWORD' "$container_name_mysql")
        
        # Handle errors for missing root password
        if [ -z "$dbrootpasswd" ]; then
            echo "Error: Failed to retrieve MySQL root password."
            return 1
        fi

        # Drop the database using the root account
        local sql_command="DROP DATABASE IF EXISTS \`${dbname}\`;"
        if ! output=$(docker exec -e MYSQL_PWD="$dbrootpasswd" "$container_name_mysql" mysql -u root -e "$sql_command" 2>&1); then
            echo "Error: Failed to delete the database '$dbname'. MySQL said: $output"
            return 1
        fi

        echo "Database '$dbname' successfully deleted."

        echo -e "\e[1;31m检测到域名证书申请失败，请检测域名是否正确解析或更换域名重新尝试！\e[0m"
    fi

}

# 站点反向代理
reverseproxy_config() {

    wget -O /home/docker/web/conf.d/$yuming.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/reverse-proxy.conf
    sed -i "s/yuming.com/$yuming/g" /home/docker/web/conf.d/$yuming.conf
    sed -i "s/0.0.0.0/$reverseproxy/g" /home/docker/web/conf.d/$yuming.conf
    sed -i "s/0000/$port/g" /home/docker/web/conf.d/$yuming.conf

    docker restart nginx

    clear
    echo "您的反向代理网站做好了！"
    echo "https://$yuming"

}

#反向代理-域名
reverseproxy_domain(){

    wget -O /home/docker/web/conf.d/$yuming.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/reverse-proxy-domain.conf
    sed -i "s/yuming.com/$yuming/g" /home/docker/web/conf.d/$yuming.conf
    sed -i "s|fandaicom|$fandai_yuming|g" /home/docker/web/conf.d/$yuming.conf
    docker restart nginx

    clear
    echo "您的反向代理-域名网站做好了！"
    echo "https://$yuming"
}

# 自定义静态站点
custom_static() {

    wget -O /home/docker/web/conf.d/$yuming.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/html.conf
    sed -i "s/yuming.com/$yuming/g" /home/docker/web/conf.d/$yuming.conf

    cd /home/docker/html
    mkdir $yuming
    cd $yuming

    clear
    echo -e "[${huang}1/2${bai}] 上传静态源码"
    echo "-------------"
    echo "目前只允许上传zip格式的源码包，请将源码包放到/home/docker/html/${yuming}目录下"
    read -p "也可以输入下载链接，远程下载源码包，直接回车将跳过远程下载： " url_download

    if [ -n "$url_download" ]; then
        wget "$url_download"
    fi

    unzip $(ls -t *.zip | head -n 1)
    rm -f $(ls -t *.zip | head -n 1)

    clear
    echo -e "[${huang}2/2${bai}] index.html所在路径"
    echo "-------------"
    find "$(realpath .)" -name "index.html" -print

    read -p "请输入index.html的路径，类似（/home/docker/html/$yuming/index/）： " index_lujing

    sed -i "s#root /var/www/html/$yuming/#root $index_lujing#g" /home/docker/web/conf.d/$yuming.conf
    sed -i "s#/home/docker/web/#/var/www/#g" /home/docker/web/conf.d/$yuming.conf

    restart_customize_app "nginx"

    clear
    echo "您的静态网站搭建好了！"
    echo "https://$yuming"
}

#  获取站点的证书到期时间
certificate_expiration_time() {
    certs_dir="/home/docker/web/certs"

    # 检查证书目录是否存在
    if [ ! -d "$certs_dir" ]; then
        echo "证书目录不存在: $certs_dir"
        return 1
    fi

    echo "站点信息                      证书到期时间"
    echo "------------------------"
    for cert_file in "$certs_dir"/*_cert.pem; do
        # 检查文件是否存在
        if [ ! -f "$cert_file" ]; then
            continue
        fi

        domain=$(basename "$cert_file" | sed 's/_cert.pem//')
        expire_date=$(openssl x509 -noout -enddate -in "$cert_file" 2>/dev/null | awk -F'=' '{print $2}')

        # 检查 openssl 命令是否成功执行
        if [ -n "$expire_date" ]; then
            formatted_date=$(date -d "$expire_date" '+%Y-%m-%d')
            printf "%-30s%s\n" "$domain" "$formatted_date"
        else
            echo "无法获取证书到期时间: $cert_file"
        fi
    done
}

# 站点管理
site_manage() {
    container_name_mysql="$1"
    while true; do
        clear
        echo "LDNMP环境"
        echo "------------------------"
        ldnmp_info
        certificate_expiration_time
        echo "------------------------"
        echo ""
        echo "数据库信息"
        echo "------------------------"
        # Get the MySQL root password from the environment variable
        dbrootpasswd=$(get_config_value 'MYSQL_ROOT_PASSWORD' "$container_name_mysql")
        docker exec mysql mysql -u root -p"$dbrootpasswd" -e "SHOW DATABASES;" 2> /dev/null | grep -Ev "Database|information_schema|mysql|performance_schema|sys"

        echo "------------------------"
        echo ""
        echo "站点目录"
        echo "------------------------"
        echo -e "数据 \e[37m/home/docker/html\e[0m     证书 \e[37m/home/docker/web/certs\e[0m     配置 \e[37m/home/docker/web/conf.d\e[0m"
        echo "------------------------"
        echo ""
        echo "操作"
        echo "------------------------"
        echo "1. 申请/更新域名证书               2. 更换站点域名"
        echo -e "3. 清理站点缓存                    4. 查看站点分析报告 \033[33mq退出模式\033[0m"
        echo "5. 查看全局配置                    6. 查看站点配置"
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
                read -p "请输入旧域名: " oldyuming
                read -p "请输入新域名: " yuming
                install_ssltls
                mv /home/docker/web/conf.d/$oldyuming.conf /home/docker/web/conf.d/$yuming.conf
                sed -i "s/$oldyuming/$yuming/g" /home/docker/web/conf.d/$yuming.conf
                mv /home/docker/html/$oldyuming /home/docker/html/$yuming

                rm /home/docker/web/certs/${oldyuming}_key.pem
                rm /home/dcoker/web/certs/${oldyuming}_cert.pem     

                docker restart nginx           
                ;;
            3)
                docker exec -it nginx rm -rf /var/cache/nginx
                docker restart nginx
                docker exec php php -r 'opcache_reset();'
                docker restart php
                docker exec php74 php -r 'opcache_reset();'
                docker restart php74
                ;;
            4)
                install goaccess
                goaccess --log-format=COMBINED /home/docker/web/log/nginx/access.log
                ;;
            5)
                install nano
                nano /home/docker/web/nginx.conf
                docker restart nginx
                ;;
            6)
                read -p "查看站点配置，请输入你的域名: " yuming
                install nano
                nano /home/docker/web/conf.d/$yuming.conf
                docker restart nginx
                ;;
            7)
                read -p "请输入你的域名: " yuming
                rm -r /home/docker/html/$yuming
                rm /home/docker/web/conf.d/$yuming.conf
                rm /home/docker/web/certs/${yuming}_key.pem
                rm /home/docker/web/certs/${yuming}_cert.pem
                docker restart nginx
                ;;
            8)
                read -p "请输入数据库名: " shujuku
                dbrootpasswd=$(get_config_value 'MYSQL_ROOT_PASSWORD' "$container_name_mysql")
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
}

# 备份全站数据
backup_site_data() {
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
                    scp -o StrictHostKeyChecking=no "$latest_tar" "root@$remote_ip:/home"
                    echo "文件已传送至远程服务器home/docker目录。"
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
}

# 定时远程备份
scheduled_remote_backup() {
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
}

# fail2ban状态
f2b_status() {
     docker restart fail2ban
     sleep 3
     docker exec -it fail2ban fail2ban-client status
}

# fail2ban带传参的状态
f2b_status_xxx() {
    docker exec -it fail2ban fail2ban-client status $xxx
}

# 不同的系统运行方式不一样
f2b_sshd() {
    if grep -q 'Alpine' /etc/issue; then
        xxx=alpine-sshd
        f2b_status_xxx
    elif grep -qi 'CentOS' /etc/redhat-release; then
        xxx=centos-sshd
        f2b_status_xxx
    else
        xxx=linux-sshd
        f2b_status_xxx
    fi
}

# fail2ban安装
f2b_install_sshd() {

    docker run -d \
        --name=fail2ban \
        --net=host \
        --cap-add=NET_ADMIN \
        --cap-add=NET_RAW \
        -e PUID=1000 \
        -e PGID=1000 \
        -e TZ=Etc/UTC \
        -e VERBOSITY=-vv \
        -v /path/to/fail2ban/config:/config \
        -v /var/log:/var/log:ro \
        -v /home/web/log/nginx/:/remotelogs/nginx:ro \
        --restart unless-stopped \
        lscr.io/linuxserver/fail2ban:latest

    sleep 3
    if grep -q 'Alpine' /etc/issue; then
        cd /path/to/fail2ban/config/fail2ban/filter.d
        curl -sS -O https://raw.githubusercontent.com/zxl2008gz/docker/main/fail2ban/alpine-sshd.conf
        curl -sS -O https://raw.githubusercontent.com/zxl2008gz/docker/main/fail2ban/alpine-sshd-ddos.conf
        cd /path/to/fail2ban/config/fail2ban/jail.d/
        curl -sS -O https://raw.githubusercontent.com/zxl2008gz/docker/main/fail2ban/alpine-ssh.conf
    elif grep -qi 'CentOS' /etc/redhat-release; then
        cd /path/to/fail2ban/config/fail2ban/jail.d/
        curl -sS -O https://raw.githubusercontent.com/zxl2008gz/docker/main/fail2ban/centos-ssh.conf
    else
        install rsyslog
        systemctl start rsyslog
        systemctl enable rsyslog
        cd /path/to/fail2ban/config/fail2ban/jail.d/
        curl -sS -O https://github.com/zxl2008gz/docker/blob/main/fail2ban/linux-ssh.conf
    fi
}

# 站点防御
site_defense_program() {
    # 站点防御程序
    if docker inspect fail2ban &>/dev/null ; then
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
            echo "21. 配置拦截参数"
            echo "------------------------"
            echo "31. cloudflare模式"
            echo "------------------------"
            echo "41. 卸载防御程序"
            echo "------------------------"
            echo "0. 退出"
            echo "------------------------"
            read -p "请输入你的选择: " sub_choice
            case $sub_choice in
                1)
                    sed -i 's/false/true/g' /path/to/fail2ban/config/fail2ban/jail.d/alpine-ssh.conf
                    sed -i 's/false/true/g' /path/to/fail2ban/config/fail2ban/jail.d/linux-ssh.conf
                    sed -i 's/false/true/g' /path/to/fail2ban/config/fail2ban/jail.d/centos-ssh.conf
                    f2b_status
                    ;;
                2)
                    sed -i 's/true/false/g' /path/to/fail2ban/config/fail2ban/jail.d/alpine-ssh.conf
                    sed -i 's/true/false/g' /path/to/fail2ban/config/fail2ban/jail.d/linux-ssh.conf
                    sed -i 's/true/false/g' /path/to/fail2ban/config/fail2ban/jail.d/centos-ssh.conf
                    f2b_status
                    ;;
                3)
                    sed -i 's/false/true/g' /path/to/fail2ban/config/fail2ban/jail.d/nginx-docker-cc.conf
                    f2b_status
                    ;;
                4)
                    sed -i 's/true/false/g' /path/to/fail2ban/config/fail2ban/jail.d/nginx-docker-cc.conf
                    f2b_status
                    ;;
                5)
                    echo "------------------------"
                    f2b_sshd
                    echo "------------------------"
                    ;;
                6)
                    echo "------------------------"
                    xxx=fail2ban-nginx-cc
                    f2b_status_xxx
                    echo "------------------------"
                    xxx=docker-nginx-bad-request
                    f2b_status_xxx
                    echo "------------------------"
                    xxx=docker-nginx-botsearch
                    f2b_status_xxx
                    echo "------------------------"
                    xxx=docker-nginx-http-auth
                    f2b_status_xxx
                    echo "------------------------"
                    xxx=docker-nginx-limit-req
                    f2b_status_xxx
                    echo "------------------------"
                    xxx=docker-php-url-fopen
                    f2b_status_xxx
                    echo "------------------------"
                    ;;

                7)
                    docker exec -it fail2ban fail2ban-client status
                    ;;
                8)
                    tail -f /path/to/fail2ban/config/log/fail2ban/fail2ban.log
                    ;;
                21)
                    install nano
                    nano /path/to/fail2ban/config/fail2ban/jail.d/nginx-docker-cc.conf
                    f2b_status
                    break
                    ;;
                31)
                    echo "到cf后台右上角我的个人资料，选择左侧API令牌，获取Global API Key"
                    echo "https://dash.cloudflare.com/login"
                    read -p "输入CF的账号: " cfuser
                    read -p "输入CF的Global API Key: " cftoken

                    wget -O /home/docker/web/conf.d/default.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/cloudflare/default.conf
                    docker restart nginx

                    cd /path/to/fail2ban/config/fail2ban/jail.d/
                    curl -sS -O https://raw.githubusercontent.com/zxl2008gz/docker/main/fail2ban/nginx-docker-cc.conf

                    cd /path/to/fail2ban/config/fail2ban/action.d
                    curl -sS -O https://raw.githubusercontent.com/zxl2008gz/docker/main/fail2ban/cloudflare-docker.conf

                    sed -i "s/cfuser@email.com/$cfuser/g" /path/to/fail2ban/config/fail2ban/action.d/cloudflare-docker.conf
                    sed -i "s/APIKEY00000/$cftoken/g" /path/to/fail2ban/config/fail2ban/action.d/cloudflare-docker.conf

                    f2b_status

                    echo "已配置cloudflare模式，可在cf后台，站点-安全性-事件中查看拦截记录"
                    ;;
                41)
                    docker rm -f fail2ban
                    rm -rf /path/to/fail2ban
                    echo "Fail2Ban防御程序已卸载"
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
    elif [ -x "$(command -v fail2ban-client)" ] ; then
        clear
        echo "卸载旧版fail2ban"

        if ask_confirmation "确定继续吗？"; then

            remove fail2ban
            rm -rf /etc/fail2ban
            echo "Fail2Ban防御程序已卸载"

        else
            echo "已取消"
        fi
    else
        clear
        if check_docker_installed; then
            echo "Docker is installed."
        else
            update_docker
        fi
        install_nginx
        docker exec -it nginx chmod -R 777 /var/www/html

        f2b_install_sshd

        cd /path/to/fail2ban/config/fail2ban/filter.d
        curl -sS -O https://raw.githubusercontent.com/zxl2008gz/sh/main/fail2ban-nginx-cc.conf
        cd /path/to/fail2ban/config/fail2ban/jail.d/
        curl -sS -O https://raw.githubusercontent.com/zxl2008gz/docker/main/fail2ban/nginx-docker-cc.conf
        sed -i "/cloudflare/d" /path/to/fail2ban/config/fail2ban/jail.d/nginx-docker-cc.conf

        cd ~
        f2b_status

        echo "防御程序已开启"
    fi       
}

# 优化LDNMP
optimize_ldnmp() {
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
                sed -i 's/worker_connections.*/worker_connections 1024;/' /home/docker/web/nginx.conf

                # php调优
                wget -O /home/optimized_php.ini https://raw.githubusercontent.com/zxl2008gz/sh/main/optimized_php.ini
                docker cp /home/optimized_php.ini php:/usr/local/etc/php/conf.d/optimized_php.ini
                docker cp /home/optimized_php.ini php74:/usr/local/etc/php/conf.d/optimized_php.ini
                rm -rf /home/optimized_php.ini

                # php调优
                wget -O /home/docker/www.conf https://raw.githubusercontent.com/zxl2008gz/sh/main/www-1.conf
                docker cp /home/docker/www.conf php:/usr/local/etc/php-fpm.d/www.conf
                docker cp /home/docker/www.conf php74:/usr/local/etc/php-fpm.d/www.conf
                rm -rf /home/docker/www.conf

                # mysql调优
                wget -O /home/docker/custom_mysql_config.cnf https://raw.githubusercontent.com/zxl2008gz/sh/main/custom_mysql_config-1.cnf
                docker cp /home/docker/custom_mysql_config.cnf mysql:/etc/mysql/conf.d/
                rm -rf /home/docker/custom_mysql_config.cnf

                docker restart nginx
                docker restart php
                docker restart php74
                docker restart mysql

                echo "LDNMP环境已设置成 标准模式"

                ;;
            2)

                # nginx调优
                sed -i 's/worker_connections.*/worker_connections 10240;/' /home/docker/web/nginx.conf

                # php调优
                wget -O /home/docker/www.conf https://raw.githubusercontent.com/zxl2008gz/sh/main/www.conf
                docker cp /home/docker/www.conf php:/usr/local/etc/php-fpm.d/www.conf
                docker cp /home/docker/www.conf php74:/usr/local/etc/php-fpm.d/www.conf
                rm -rf /home/docker/www.conf

                # mysql调优
                wget -O /home/docker/custom_mysql_config.cnf https://raw.githubusercontent.com/zxl2008gz/sh/main/custom_mysql_config.cnf
                docker cp /home/docker/custom_mysql_config.cnf mysql:/etc/mysql/conf.d/
                rm -rf /home/docker/custom_mysql_config.cnf

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
}

# 获取 Docker 容器所在的网络
get_docker_network() {
    local container_name=$1
    docker inspect "$container_name" --format '{{range .NetworkSettings.Networks}}{{.NetworkID}}{{end}}'
}

# 获取docker 端口
get_docker_port() {
    local container_name=$1
    # 使用 grep 和 awk 提取端口号
    local ports=$(docker inspect "$container_name" | grep "HostPort" | awk -F '"' '{print $(NF-1)}' | head -n 1)
    echo $ports
}

# 通用函数，用于清理并重新启动容器
restart_container() {
    docker rm -f "$docker_name" &>/dev/null
    docker rmi -f "$docker_img" &>/dev/null
}

# 设置反向代理
reverse_proxy() {
    read ipv4_address ipv6_address < <(get_ip_address)
    wget -O /home/docker/web/conf.d/$yuming.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/reverse-proxy.conf
    sed -i "s/yuming.com/$yuming/g" /home/docker/web/conf.d/$yuming.conf
    sed -i "s/0.0.0.0/$ipv4_address/g" /home/docker/web/conf.d/$yuming.conf
    sed -i "s/0000/$docker_port/g" /home/docker/web/conf.d/$yuming.conf

    docker restart nginx
}


# docker app 输出
docker_output() {
    clear
    echo "$docker_name 已经安装完成"
    echo "------------------------"  
    
    # 获取外部 IP 地址
    read ipv4_address ipv6_address < <(get_ip_address)
    
    # 根据是否有域名显示不同的访问地址
    if [ -z "$yuming" ]; then
        echo "您可以使用以下地址访问:"
        echo "http:$ipv4_address:$docker_port"
    else
        reverse_proxy
        echo "您可以使用以下地址访问:"
        echo "https://$yuming"
        echo "http:$ipv4_address:$docker_port"
    fi

    # 显示用户名密码等信息
    $docker_use
    $docker_passwd
}

# 安装应用
docker_app() {
    has_ipv4_has_ipv6
    if docker inspect "$docker_name" &>/dev/null; then
        clear
        echo "$docker_name 已安装，访问地址: "
        read ipv4_address ipv6_address < <(get_ip_address)
        port_number=$(get_docker_port "$docker_name")
        echo "http:$ipv4_address:$port_number"
        echo ""
        echo "应用操作"
        echo "------------------------"
        echo "1. 更新应用             2. 卸载应用"
        echo "------------------------"
        echo "0. 返回上一级选单"
        echo "------------------------"
        read -p "请输入你的选择: " sub_choice

        case $sub_choice in
            1)
                clear
                restart_container
                eval "$docker_run"
                docker_output                                   
                ;;
            2)
                clear
                restart_container
                rm -rf "/home/docker/$docker_name"
                del_db "$docker_name"
                echo "应用已卸载"
                ;;
            0)
                # 跳出循环，退出菜单
                ;;
            *)
                # 跳出循环，退出菜单
                ;;
        esac
    else
        clear
        echo "安装提示"
        echo "$docker_describe"
        echo "$docker_url"
        echo ""

        # 提示用户确认安装
        if ask_confirmation "确定安装吗？"; then
            clear
            # 安装 Docker（请确保有 install_docker 函数）
            if check_docker_installed; then
                echo "Docker is installed."
            else
                update_docker
            fi
            eval "$docker_run"
            docker_output
        else
            echo "安装已取消。"
        fi
    fi

}

# 安装epusdt收款地址
install_epusdt() {

    epusdt_path="$1"
    local container_name1="$2"
    local container_name_mysql=$(get_db_container_name "$container_name1")
    local credentials=($(get_db_credentials "$container_name_mysql"))

    # 获取 Docker 容器所在的网络
    network_name=$(get_docker_network "$container_name_mysql")

    docker_name=$(get_default_data "请输入项目名称" "epusdt" "20")
    docker_port=$(get_default_data "请输入外部端口" "8000" "20")

    dbuse=${credentials[0]}
    dbusepasswd=${credentials[1]}

    mkdir -p "$epusdt_path/$docker_name" && chmod -R 777 $docker_name && cd "$epusdt_path/$docker_name"
    wget -O "$epusdt_path/$docker_name/epusdt.conf" https://raw.githubusercontent.com/zxl2008gz/docker/main/epusdt/epusdt.conf
    sed -i "s|mysql_user=epusdt|mysql_user=$dbuse|g" "$epusdt_path/$docker_name/epusdt.conf"	
    sed -i "s|changeyourpassword|$dbusepasswd|g" "$epusdt_path/$docker_name/epusdt.conf"	
    read -p "请输入你的tg机器人token: " tg_bot_token
    sed -i "s/你的tg机器人token/$tg_bot_token/g" "$epusdt_path/$docker_name/epusdt.conf"
    read -p "请输入你的tgid: " tg_id
    sed -i "s/你的tgid/$tg_id/g" "$epusdt_path/$docker_name/epusdt.conf" 

    add_db "$docker_name"
    wget -O "$epusdt_path/$docker_name/epusdt.sql" https://raw.githubusercontent.com/zxl2008gz/docker/main/epusdt/epusdt.sql

    # 设定数据文件的路径，你需要根据实际情况修改此路径
	datafile="$epusdt_path/$docker_name/epusdt.sql"

    # 使用 Docker 执行 MySQL 命令来导入数据
    if ! docker exec -i -e MYSQL_PWD="$dbusepasswd" "$container_name_mysql" mysql -u "$dbuse" "$dbname" < "$datafile"; then
        echo "Error: Failed to import data to the database."
        return 1
    fi
    echo "Data successfully imported to database '$dbname'."

    docker_img="stilleshan/epusdt:latest"
    docker_run="docker run -d \
                    --name=$docker_name \
                    -p $docker_port:8000 \
                    --network $network_name \
                    -e mysql_host=mysql \
                    -e mysql_database=$docker_name \
                    -e mysql_user=$dbuse \
                    -e mysql_passwd=$dbusepasswd \
                    -v $epusdt_path/$docker_name/epusdt.conf:/app/.env \
                    --restart=always \
                    $docker_img"
    docker_describe="EPUSDT（Ether Pay USD Token）是一种基于区块链技术的数字货币，主要目标是提供一种稳定且安全的支付方式。它通常被用作数字资产交易、跨境支付、在线购物等领域的支付工具。"
    docker_url=""
    docker_use='echo -e "安装信息如下： \n数据库地址: mysql \n数据库用户名: '"$dbuse"'\n密码: '"$dbusepasswd"'\n数据库名: '"$docker_name"' "'
    docker_passwd='echo -e "商户ID: '$dbusepasswd'\n商户密钥: https://你的域名/api/v1/order/create-transaction"'
    docker_passwd1='echo -e "商户ID: '$dbusepasswd'\n商户密钥: https://'$yuming'/api/v1/order/create-transaction"'
    docker_app    
}

# 安装LobeChat聊天网站
install_lobe() {

    container_name_mysql="$1"

    docker_name=$(get_default_data "请输入项目名称" "lobe_chat" "20")
    docker_port=$(get_default_data "请输入外部端口" "3210" "20")

    openai_key=$(get_default_data "请输入你的OPENAI_API_KEY" "" "20")
    gemini_key=$(get_default_data "请输入你的GOOGLE_API_KEY" "" "20")
    claude_key=$(get_default_data "请输入你的CLAUDE_API_KEY" "" "20")

    dbusepasswd=$(get_config_value 'MYSQL_PASSWORD' "$container_name_mysql")

    docker_img="lobehub/lobe-chat"

    docker_run="docker run -d \
                    --name=$docker_name \
                    -p $docker_port:3210 \
                    -e OPENAI_API_KEY=$openai_key \
                    -e GOOGLE_API_KEY=$gemini_key \
                    -e ANTHROPIC_API_KEY=$claude_key \
                    -e ACCESS_CODE=$dbusepasswd \
                    -e HIDE_USER_API_KEY=1 \
                    --restart=always \
                    $docker_img"
    docker_describe="LobeChat 现在支持 OpenAI/GOOGLE/CLAUDE 3最新的模型，具备视觉识别能力，这是一种能够感知视觉内容的多模态智能。"
    docker_url="官网介绍: https://github.com/lobehub/lobe-chat"
    docker_use='echo -e "密码: '"$dbusepasswd"'"'
    docker_passwd=""
    docker_passwd1=""
    docker_app
}

# 安装GeminiPro聊天网站
install_geminiPro() {

    docker_name=$(get_default_data "请输入项目名称" "geminiprochat" "20")
    docker_port=$(get_default_data "请输入外部端口" "3020" "20")

    read -p "请输入你的GEMINI_API_KEY: " apikey
    docker_img="babaohuang/geminiprochat:latest"
    docker_run="docker run -d \
                    --name=$docker_name \
                    -p $docker_port:3000 \
                    -itd \
                    -e GEMINI_API_KEY=$apikey \
                    --restart=always \
                    $docker_img"
    docker_describe="Gemini 是由谷歌开发的一款高能力、多功能的人工智能模型。它具有多模态能力，能够处理和组合包括文本、代码、音频、图像和视频在内的多种信息类型。"
    docker_url="官网介绍: https://blog.google/technology/ai/google-gemini-ai/"
    docker_use=""
    docker_passwd=""
    docker_passwd1=""    
    docker_app    
}

# 安装vaultwarden密码管理平台
install_vaultwarden() {

    vaultwarden_path="$1"

    docker_name=$(get_default_data "请输入项目名称" "vaultwarden" "20")
    docker_port=$(get_default_data "请输入外部端口" "8050" "20")

    docker_img="vaultwarden/server:latest"
    docker_run="docker run -d \
                    --name=$docker_name \
                    -p $docker_port:80 \
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
                    -v $vaultwarden_path/$docker_name:/data \
                    --restart=always \
                    $docker_img"
    docker_describe="Bitwarden 是一款广受欢迎的开源密码管理器，它提供了一个安全的方式来存储和管理个人和工作上的各种密码和敏感信息。"
    docker_url="官网介绍: https://bitwarden.com"
    docker_use=""
    docker_passwd=""
    docker_passwd1=""
    docker_app    
}

# onlyoffice在线办公OFFICE
install_onlyoffice() {

    onlyoffice_path="$1"  

    docker_name=$(get_default_data "请输入项目名称" "onlyoffice" "20")
    docker_port=$(get_default_data "请输入外部端口" "8082" "20")

    docker_img="onlyoffice/documentserver"
    docker_run="docker run -d \
                    --name $docker_name \
                    -p $docker_port:80 \
                    -v $onlyoffice_path/$docker_name/DocumentServer/logs:/var/log/onlyoffice \
                    -v $onlyoffice_path/$docker_name/DocumentServer/data:/var/www/onlyoffice/Data \
                    --restart=always \
                    $docker_img"
    docker_describe="onlyoffice是一款开源的在线office工具，太强大了！"
    docker_url="官网介绍: https://www.onlyoffice.com/"
    docker_use=""
    docker_passwd=""
    docker_passwd1=""    
    docker_app
}

# nextcloud网盘
install_nextcloud() {

    nextcloud_path="$1"
    local container_name1="$2"
    local container_name_mysql=$(get_db_container_name "$container_name1")
    local credentials=($(get_db_credentials "$container_name_mysql"))

    dbuse=${credentials[0]}
    dbusepasswd=${credentials[1]}

    # 获取 Docker 容器所在的网络
    network_name=$(get_docker_network "$container_name_mysql")

    docker_name=$(get_default_data "请输入项目名称" "nextcloud" "20")
    docker_port=$(get_default_data "请输入外部端口" "8989" "20")

    add_db "$docker_name"

    mkdir -p "$nextcloud_path/$docker_name"
    wget -O "$nextcloud_path/$docker_name/Dockerfile" https://raw.githubusercontent.com/zxl2008gz/docker/main/nextcloud/Dockerfile
    docker build -t nextcloud-with-bz2 "$nextcloud_path/$docker_name"

    docker_img="nextcloud:latest"
    docker_run="docker run -d \
                    --name $docker_name \
                    --restart=always \
                    --network $network_name \
                    -p $docker_port:80 \
                    -v $nextcloud_path/$docker_name/nextcloud_data:/var/www/html \
                    nextcloud-with-bz2"
    docker_describe="Nextcloud拥有超过 400,000 个部署，是您可以下载的最受欢迎的本地内容协作平台"
    docker_url="官网介绍: https://nextcloud.com/"
    docker_use='echo -e "安装信息如下： \n数据库地址: mysql \n数据库用户名: '"$dbuse"'\n密码: '"$dbusepasswd"'\n数据库名: '"$docker_name"' "'
    docker_passwd=""
    docker_app
}

# speedtest测试
install_speedtest() {

    docker_name=$(get_default_data "请输入项目名称" "looking-glass" "20")
    docker_port=$(get_default_data "请输入外部端口" "89" "20")

    docker_img="wikihostinc/looking-glass-server"
    docker_run="docker run -d --name $docker_name --restart always -p $docker_port:80 $docker_img"
    docker_describe="Speedtest测速面板是一个VPS网速测试工具，多项测试功能，还可以实时监控VPS进出站流量"
    docker_url="官网介绍: https://github.com/wikihost-opensource/als"
    docker_use=""
    docker_passwd=""
    docker_app
}

# portainer容器管理面板
install_portainer() {

    portainer_path="$1"

    docker_name=$(get_default_data "请输入项目名称" "portainer" "20")
    docker_port=$(get_default_data "请输入外部端口" "9050" "20")

    docker_img="portainer/portainer"
    docker_run="docker run -d \
            --name $docker_name \
            -p $docker_port:9000 \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v $portainer_path/$docker_name:/data \
            --restart always \
            $docker_img"
    docker_describe="portainer是一个轻量级的docker容器管理面板"
    docker_url="官网介绍: https://www.portainer.io/"
    docker_use=""
    docker_passwd=""
    docker_app
}

# 邮件服务程序
install_Poste() {
    if docker inspect mailserver &>/dev/null; then

        clear
        echo "poste.io已安装，访问地址: "
        yuming=$(cat /home/docker/mail.txt)
        echo "https://$yuming"
        echo ""

        echo "应用操作"
        echo "------------------------"
        echo "1. 更新应用             2. 卸载应用"
        echo "------------------------"
        echo "0. 返回上一级选单"
        echo "------------------------"
        read -p "请输入你的选择: " sub_choice

        case $sub_choice in
            1)
                clear
                docker rm -f mailserver
                docker rmi -f analogic/poste.io

                yuming=$(cat /home/docker/mail.txt)
                docker run \
                    --net=host \
                    -e TZ=Europe/Prague \
                    -v /home/docker/mail:/data \
                    --name "mailserver" \
                    -h "$yuming" \
                    --restart=always \
                    -d analogic/poste.io

                clear
                echo "poste.io已经安装完成"
                echo "------------------------"
                echo "您可以使用以下地址访问poste.io:"
                echo "https://$yuming"
                echo ""
                ;;
            2)
                clear
                docker rm -f mailserver
                docker rmi -f analogic/poste.io
                rm /home/docker/mail.txt
                rm -rf /home/docker/mail
                echo "应用已卸载"
                ;;
            0)
                break  # 跳出循环，退出菜单
                ;;
            *)
                break  # 跳出循环，退出菜单
                ;;
        esac
    else
        clear
        install telnet

        clear
        echo ""
        echo "端口检测"
        port=25
        timeout=3

        if echo "quit" | timeout $timeout telnet smtp.qq.com $port | grep 'Connected'; then
            echo -e "\e[32m端口$port当前可用\e[0m"
        else
            echo -e "\e[31m端口$port当前不可用\e[0m"
        fi
        echo "------------------------"
        echo ""

        echo "安装提示"
        echo "poste.io一个邮件服务器，确保80和443端口没被占用，确保25端口开放"
        echo "官网介绍: https://hub.docker.com/r/analogic/poste.io"
        echo ""

        # 提示用户确认安装
        if ask_confirmation "确定安装poste.io吗？"; then
                clear
                read -p "请设置邮箱域名 例如 mail.yuming.com : " yuming
                mkdir -p /home/docker      # 递归创建目录
                echo "$yuming" > /home/docker/mail.txt  # 写入文件
                echo "------------------------"
                ip_address
                echo "先解析这些DNS记录"
                echo "A           mail            $ipv4_address"
                echo "CNAME       imap            $yuming"
                echo "CNAME       pop             $yuming"
                echo "CNAME       smtp            $yuming"
                echo "MX          @               $yuming"
                echo "TXT         @               v=spf1 mx ~all"
                echo "TXT         ?               ?"
                echo ""
                echo "------------------------"
                echo "按任意键继续..."
                read -n 1 -s -r -p ""

                install_docker

                docker run \
                    --net=host \
                    -e TZ=Europe/Prague \
                    -v /home/docker/mail:/data \
                    --name "mailserver" \
                    -h "$yuming" \
                    --restart=always \
                    -d analogic/poste.io

                clear
                echo "poste.io已经安装完成"
                echo "------------------------"
                echo "您可以使用以下地址访问poste.io:"
                echo "https://$yuming"
                echo ""
        else
            echo "取消安装"
        fi
    fi
}

# 安装halo网站
install_halo() {

    halo_path="$1"s
    local container_name1="$2"
    local container_name_mysql=$(get_db_container_name "$container_name1")
    local credentials=($(get_db_credentials "$container_name_mysql"))

    local dbuse=${credentials[0]}
    local dbusepasswd=${credentials[1]}

    # 获取 Docker 容器所在的网络
    network_name=$(get_docker_network "$container_name_mysql")

    docker_name=$(get_default_data "请输入项目名称" "halo" "20")
    docker_port=$(get_default_data "请输入外部端口" "8010" "20")

    add_db "$docker_name"
 
    docker_img="halohub/halo:2.11"

    docker_run="docker run -d \
                    --name=$docker_name \
                    --restart on-failure:3 \
                    --network $network_name \
                    -p $docker_port:8090 \
                    -v $halo_path/$docker_name/.halo2:/root/.halo2 \
                    $docker_img \
                    --spring.r2dbc.url=r2dbc:pool:mysql://mysql_host:3306/halo \
                    --spring.r2dbc.username=$dbuse \
                    --spring.r2dbc.password=$dbusepasswd \
                    --spring.sql.init.platform=mysql \
                    --halo.security.initializer.superadminusername=admin \
                    --halo.security.initializer.superadminpassword=P@88w0rd"

    docker_describe="Halo 是一个用 Java 编写的现代化博客系统（博客引擎），它配备了一个简洁且功能丰富的界面，旨在为用户提供轻松的博客搭建和管理体验。Halo 的设计哲学是提供一个简单、优雅且高度可定制的平台，使得个人博客的搭建变得快速和简单。"
    docker_url="官网介绍: https://halo.run/"
    docker_use=""
    docker_passwd=""
    docker_passwd1=""
    docker_app       
}

# QB离线BT磁力下载面板
install_qbittorrent() {

    qbittorrent_paht="$1"

    docker_name=$(get_default_data "请输入项目名称" "qbittorrent" "20")
    docker_port=$(get_default_data "请输入外部端口" "8081" "20")

    docker_img="lscr.io/linuxserver/qbittorrent:latest"
    docker_run="docker run -d \
                    --name=$docker_name \
                    --restart unless-stopped \
                    -e PUID=1000 \
                    -e PGID=1000 \
                    -e TZ=Etc/UTC \
                    -e WEBUI_PORT=$docker_port \
                    -p $docker_port:8081 \
                    -p 6881:6881 \
                    -p 6881:6881/udp \
                    -v $qbittorrent_paht/$docker_name/config:/config \
                    -v $qbittorrent_paht/$docker_name/downloads:/downloads \
                    $docker_img"
    docker_describe="qbittorrent离线BT磁力下载服务"
    docker_url="官网介绍: https://hub.docker.com/r/linuxserver/qbittorrent"
    docker_use="sleep 3"
    docker_passwd="docker logs qbittorrent"
    docker_passwd1=""
    docker_app     
}

# vscode网页版
install_vscode_web() {
    vscode_web_path="$1"

    docker_name=$(get_default_data "请输入项目名称" "vscode_web" "20")
    docker_port=$(get_default_data "请输入外部端口" "8180" "20")

    docker_img="codercom/code-server"
    docker_run="docker run -d \
                    --name=$docker_name \
                    --restart always \
                    -p $docker_port:8080 \
                    -v $vscode_web_path/$docker_name/vscodeweb:/home/coder/.local/share/code-server \
                    $docker_img"
    docker_describe="VScode是一款强大的在线代码编写工具"
    docker_url="官网介绍: https://github.com/coder/code-server"
    docker_use="sleep 3"
    docker_passwd="docker exec vscode_web cat /home/coder/.config/code-server/config.yaml"
    docker_passwd1=""
    docker_app   
}

# UptimeKuma监控工具
install_UptimeKuma() {
    UptimeKuma_path="$1"

    docker_name=$(get_default_data "请输入项目名称" "uptimeKuma" "20")
    docker_port=$(get_default_data "请输入外部端口" "3003" "20")

    docker_img="louislam/uptime-kuma:latest"
    docker_run="docker run -d \
                    --name=$docker_name \
                    --restart always \
                    -p $docker_port:3001 \
                    -v $UptimeKuma_path/$docker_name/uptime-kuma-data:/app/data \
                    $docker_img"
    docker_describe="Uptime Kuma 易于使用的自托管监控工具"
    docker_url="官网介绍: https://github.com/louislam/uptime-kuma"
    docker_use=""
    docker_passwd=""
    docker_passwd1=""
    docker_app   
}

# cloudreve 配置
cloudreve_config() {
    cd /home/ && mkdir -p docker/cloud && cd docker/cloud && mkdir temp_data && mkdir -vp cloudreve/{uploads,avatar} && touch cloudreve/conf.ini && touch cloudreve/cloudreve.db && mkdir -p aria2/config && mkdir -p data/aria2 && chmod -R 777 data/aria2
    curl -o /home/docker/cloud/docker-compose.yml https://raw.githubusercontent.com/zxl2008gz/docker/main/cloudreve/cloudreve-docker-compose.yml

    docker_name=$(get_default_data "请输入项目名称" "cloudreve" "20")
    docker_port=$(get_default_data "请输入外部端口" "5212" "20")
    sed -i "s/5212:5212/$docker_port:5212/g" /home/docker/cloud/docker-compose.yml
    cd /home/docker/cloud/ && docker-compose up -d
}

#判断存在ipv4还是ipv6
has_ipv4_has_ipv6() {

    read ipv4_address ipv6_address < <(get_ip_address)
    if [ -z "$ipv4_address" ]; then
        has_ipv4=false
    else
        has_ipv4=true
    fi

    if [ -z "$ipv6_address" ]; then
        has_ipv6=false
    else
        has_ipv6=true
    fi
}

#安装cloudreve
install_cloudreve() {

    has_ipv4_has_ipv6

    if docker inspect cloudreve &>/dev/null; then
        clear
        echo "cloudreve已安装，访问地址: "
        read ipv4_address ipv6_address < <(get_ip_address)
        port_number=$(get_docker_port "$docker_name")
        echo "http:$ipv4_address:$port_number"
        echo ""

        echo "应用操作"
        echo "------------------------"
        echo "1. 更新应用             2. 卸载应用"
        echo "------------------------"
        echo "0. 返回上一级选单"
        echo "------------------------"
        read -p "请输入你的选择: " sub_choice

        case $sub_choice in
            1)
                clear
                docker rm -f cloudreve
                docker rmi -f cloudreve/cloudreve:latest
                docker rm -f aria2
                docker rmi -f p3terx/aria2-pro

                cloudreve_config

                clear
                echo "cloudreve已经安装完成"
                echo "------------------------"
                echo "您可以使用以下地址访问cloudreve:"
                echo "https://$yuming"
                if $has_ipv4; then
                    echo "http:$ipv4_address:$port_number"
                fi
                if $has_ipv6; then
                    echo "http:[$ipv6_address]:$port_number"
                fi

                sleep 3
                docker logs cloudreve
                echo ""
                ;;
            2)
                clear
                docker rm -f cloudreve
                docker rmi -f cloudreve/cloudreve:latest
                docker rm -f aria2
                docker rmi -f p3terx/aria2-pro
                rm -rf /home/docker/cloud
                echo "应用已卸载"
                ;;
            0)
                break  # 跳出循环，退出菜单
                ;;
            *)
                break  # 跳出循环，退出菜单
                ;;
        esac
    else
        clear
        echo "安装提示"
        echo "cloudreve是一个支持多家云存储的网盘系统"
        echo "官网介绍: https://cloudreve.org/"
        echo ""

        # 提示用户确认安装
        read -p "确定安装cloudreve吗？(Y/N): " choice
        case "$choice" in
            [Yy])
                clear
                install_docker
                cloudreve_config

                clear
                echo "cloudreve已经安装完成"
                echo "------------------------"
                echo "您可以使用以下地址访问cloudreve:"
                echo "https://$yuming"
                if $has_ipv4; then
                    echo "http:$ipv4_address:$port_number"
                fi
                if $has_ipv6; then
                    echo "http:[$ipv6_address]:$port_number"
                fi

                sleep 3
                docker logs cloudreve
                echo ""

                ;;
            [Nn])
                ;;
            *)
                ;;
        esac
    fi    
}

# librespeed测速工具
install_librespeed() {

    docker_name=$(get_default_data "请输入项目名称" "librespeed" "20")
    docker_port=$(get_default_data "请输入外部端口" "6681" "20")
    
    docker_img="ghcr.io/librespeed/speedtest:latest"
    docker_run="docker run -d \
                    --name=$docker_name \
                    --restart always \
                    -e MODE=standalone \
                    -p $docker_port:80 \
                    $docker_img"
    docker_describe="librespeed是用Javascript实现的轻量级速度测试工具，即开即用"
    docker_url="官网介绍: https://github.com/librespeed/speedtest"
    docker_use=""
    docker_passwd=""
    docker_passwd1=""
    docker_app      
}

# searxng聚合搜索站
install_searxng() {

    searxng_path="$1"

    docker_name=$(get_default_data "请输入项目名称" "searxng" "20")
    docker_port=$(get_default_data "请输入外部端口" "8700" "20")
    
    docker_img="alandoyle/searxng:latest"
    docker_run="docker run -d \
                    --name=$docker_name \
                    --restart=unless-stopped \
                    --init \
                    -p $docker_port:8080 \
                    -v $searxng_path/$docker_name/config:/etc/searxng \
                    -v $searxng_path/$docker_name/templates:/usr/local/searxng/searx/templates/simple \
                    -v $searxng_path/$docker_name/theme:/usr/local/searxng/searx/static/themes/simple \
                    $docker_img"
    docker_describe="searxng是一个私有且隐私的搜索引擎站点"
    docker_url="官网介绍: https://hub.docker.com/r/alandoyle/searxng"
    docker_use=""
    docker_passwd=""
    docker_passwd1=""
    docker_app      
}

# photoprism私人相册
install_photoprism() {

    photoprism_path="$1"

    docker_name=$(get_default_data "请输入项目名称" "photoprism" "20")
    docker_port=$(get_default_data "请输入外部端口" "2342" "20")
    
    docker_img="photoprism/photoprism:latest"
    rootpasswd=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c16)
    docker_run="docker run -d \
                    --name=$docker_name \
                    --restart=always \
                    -p $docker_port:2342 \
                    --security-opt seccomp=unconfined \
                    --security-opt apparmor=unconfined \
                    -e PHOTOPRISM_UPLOAD_NSFW="true" \
                    -e PHOTOPRISM_ADMIN_PASSWORD="$rootpasswd" \
                    -v $photoprism_path/$docker_name/storage:/photoprism/storage \
                    -v $photoprism_path/$docker_name/Pictures:/photoprism/originals \
                    $docker_img"
    docker_describe="photoprism非常强大的私有相册系统"
    docker_url="官网介绍: https://www.photoprism.app/"
    docker_use="echo \"账号: admin  密码: $rootpasswd\""
    docker_passwd=""
    docker_passwd1=""
    docker_app        
} 

# StirlingPDF工具大全
install_s_pdf() {

    s_pdf_path="$1"

    docker_name=$(get_default_data "请输入项目名称" "s_pdf" "20")
    docker_port=$(get_default_data "请输入外部端口" "8020" "20")

    docker_img="frooodle/s-pdf:latest"
    docker_run="docker run -d \
                    --name=$docker_name \
                    --restart=always \
                    -p $docker_port:8080 \
                    -v $s_pdf_path/$docker_name/trainingData:/usr/share/tesseract-ocr/5/tessdata \
                    -v $s_pdf_path/$docker_name/extraConfigs:/configs \
                    -v $s_pdf_path/$docker_name/logs:/logs \
                    -e DOCKER_ENABLE_SECURITY=false \
                    $docker_img"
    docker_describe="这是一个强大的本地托管基于 Web 的 PDF 操作工具，使用 docker，允许您对 PDF 文件执行各种操作，例如拆分合并、转换、重新组织、添加图像、旋转、压缩等。"
    docker_url="官网介绍: https://github.com/Stirling-Tools/Stirling-PDF"
    docker_use=""
    docker_passwd=""
    docker_passwd1=""
    docker_app   
}

# drawio免费的在线图表软件
install_drawio() {

    drawio_path="$1"

    docker_name=$(get_default_data "请输入项目名称" "drawio" "20")
    docker_port=$(get_default_data "请输入外部端口" "7080" "20")

    docker_img="jgraph/drawio"
    docker_run="docker run -d \
                    --name=$docker_name \
                    --restart=always \
                    -p $docker_port:8080 \
                    -v $drawio_path/$docker_name:/var/lib/drawio \
                    $docker_img"
    docker_describe="这是一个强大图表绘制软件。思维导图，拓扑图，流程图，都能画"
    docker_url="官网介绍: https://www.drawio.com/"
    docker_use=""
    docker_passwd=""
    docker_passwd1=""
    docker_app
}

# 安装nginx-proxy-manager管理工具
nginx-proxy-manager() {

    nginx-proxy-manager="$1"

    docker_name=$(get_default_data "请输入项目名称" "npm" "20")
    docker_port=$(get_default_data "请输入外部端口" "81" "20")

    docker_img="jc21/nginx-proxy-manager:latest"
    docker_run="docker run -d \
                    --name=$docker_name \
                    -p 80:80 \
                    -p $docker_port:81 \
                    -p 443:443 \
                    -v ${nginx-proxy-manager}/$docker_name/data:/data \
                    -v ${nginx-proxy-manager}/$docker_name/letsencrypt:/etc/letsencrypt \
                    --restart=always \
                    $docker_img"
    docker_describe="如果您已经安装了其他面板工具或者LDNMP建站环境，建议先卸载，再安装npm！"
    docker_url="官网介绍: https://nginxproxymanager.com/"
    docker_use="echo \"初始用户名: admin@example.com\""
    docker_passwd="echo \"初始密码: changeme\""
    docker_app
}

# 安装kodbox可道云网盘
install_kodbox() {

    kodbox_path="$1"

    local container_name1="$2"
    local container_name_mysql=$(get_db_container_name "$container_name1")
    local credentials=($(get_db_credentials "$container_name_mysql"))

    local dbuse=${credentials[0]}
    local dbusepasswd=${credentials[1]}

    # 获取 Docker 容器所在的网络
    network_name=$(get_docker_network "$container_name_mysql")

    docker_name=$(get_default_data "请输入项目名称" "kodbox" "20")
    docker_port=$(get_default_data "请输入外部端口" "8980" "20")

    docker_img="kodcloud/kodbox:latest"
    add_db "$docker_name"

    docker_run="docker run -d \
                    --name=$docker_name \
                    -p $docker_port:80 \
                    -e ROCKET_PORT=$docker_port \
                    --network $network_name \
                    -v $kodbox_path/$docker_name:/var/www/html \
                    --restart=always \
                    $docker_img"
    docker_describe="可道云（Kodexplorer）是一个基于网络的文件管理系统，它提供了丰富的功能，如在线文件浏览、编辑、上传、下载和预览等。它支持多种文件格式，并提供了类似于桌面操作系统的用户界面。"
    docker_url="官网介绍: https://www.kodcloud.com"
    # 变量赋值
    docker_use='echo -e "安装信息如下： \n数据库地址: mysql \n数据库用户名: '"$dbuse"'\n密码: '"$dbusepasswd"'\n数据库名: '"$docker_name"' "'
    docker_passwd='echo "redis主机: redis"'
    docker_app    
}

# 安装dujiaoka独角数发卡网
install_dujiaoka() {

    dujiaoka_path="$1"

    local container_name1="$2"
    local container_name_mysql=$(get_db_container_name "$container_name1")
    local credentials=($(get_db_credentials "$container_name_mysql"))

    local dbuse=${credentials[0]}
    local dbusepasswd=${credentials[1]}

    # 获取 Docker 容器所在的网络
    network_name=$(get_docker_network "$container_name_mysql")

    docker_name=$(get_default_data "请输入项目名称" "dujiaoka" "20")
    docker_port=$(get_default_data "请输入外部端口" "8920" "20")

    add_db "$docker_name"
    mkdir -p "$dujiaoka_path/$docker_name" && cd "$dujiaoka_path/$docker_name" && mkdir storage uploads && chmod -R 777 storage uploads && touch env.conf && chmod -R 777 env.conf
    wget -O "$dujiaoka_path/$docker_name/env.conf" https://raw.githubusercontent.com/zxl2008gz/docker/main/dujiaoka/env.conf
    sed -i "s/mysqlbase/$docker_name/g" "$dujiaoka_path/$docker_name/env.conf"
    sed -i "s/mysqluse/$dbuse/g" "$dujiaoka_path/$docker_name/env.conf"
    sed -i "s/mysqlpasswd/$dbusepasswd/g" "$dujiaoka_path/$docker_name/env.conf"

    docker_img="stilleshan/dujiaoka:latest"

    docker_run="docker run -d \
                    --name=$docker_name \
                    -p $docker_port:80 \
                    --network $network_name \
                    -e INSTALL=true \
                    -v $dujiaoka_path/$docker_name/env.conf:/dujiaoka/.env \
                    -v $dujiaoka_path/$docker_name/uploads:/dujiaoka/public/uploads \
                    -v $dujiaoka_path/$docker_name/storage:/dujiaoka/storage \
                    --restart=always \
                    $docker_img"
    docker_describe="独角数发卡网是一个自动化售货网站源码，支持多种支付方式，包括支付宝、微信、QQ钱包等，并且可以通过USDT进行收款。它的特点是简单易用、高效稳定，能够帮助站长快速搭建自己的售货系统。"
    docker_url=""
    docker_use='echo -e "安装信息如下： \n数据库地址: mysql \n数据库用户名: '"$dbuse"'\n密码: '"$dbusepasswd"'\n数据库名: '"$docker_name"' "'
    docker_passwd='echo -e "redis主机: redis \nredis密码: 默认不填写 \nredis端口: 6379 \n用户名: admin \n密码: admin \n登录时右上角如果出现红色error0请使用如下命令: \n我也很气愤独角数卡为啥这么麻烦，会有这样的问题！ \nsed -i 's/ADMIN_HTTPS=false/ADMIN_HTTPS=true/g' '${dujiaoka_path}/${docker_name}/env.conf'"'
    docker_app    
}

#system_info路径
system_info_path(){
    # 切换到一个一致的目录（例如，家目录）
    cd ~ || exit

    # 下载并使脚本可执行
    curl -O https://raw.githubusercontent.com/zxl2008gz/sh/main/system_info.sh
    chmod +x system_info.sh
}

#系统信息查询
system_info_query(){
    system_info_path
    ./system_info.sh query
}

#系统更新
update_service_info(){
    system_info_path
    ./system_info.sh update
}

#系统清理
clean_service_info(){
    system_info_path
    ./system_info.sh clean
}

#常用工具
common_tool_install(){
    system_info_path
    ./system_info.sh commontool
}

#BBR脚本管理
bbr_script(){
    system_info_path
    ./system_info.sh bbr
}

#测试脚本管理
test_script(){
    system_info_path
    ./system_info.sh test
}

#甲骨文脚本管理
oracle_script(){
    system_info_path
    ./system_info.sh oracle
}

#谷歌云脚本管理
gcp_script(){
    system_info_path
    ./system_info.sh gcp
}

#docker脚本路径
docker_script_path() {
    # 切换到一个一致的目录（例如，家目录）
    cd ~ || exit
    curl -O https://raw.githubusercontent.com/zxl2008gz/sh/main/docker_manage_info.sh
    chmod +x docker_manage_info.sh
}

#docker管理
docker_manage() {
    docker_script_path
    ./docker_manage_info.sh manage
}

#mysql脚本路径
db_script_path() {
    # 切换到一个一致的目录（例如，家目录）
    cd ~ || exit
    curl -O https://raw.githubusercontent.com/zxl2008gz/sh/main/mysql_db_manager.sh
    chmod +x mysql_db_manager.sh
}

#MYSQL管理
mysql_db_manage(){
    db_script_path
    ./mysql_db_manager.sh manage mysql
}

# 安装数据库
install_db_mysql() {
    db_script_path
    ./mysql_db_manager.sh install mysql
}

# 添加数据库
add_db() {
    local project_name="$1"
    # 规范化数据库名称,移除非法字符
    dbname=$(echo "$project_name" | sed 's/[^A-Za-z0-9_]/_/g')

    db_script_path
    if ! ./mysql_db_manager.sh create "mysql" "$dbname"; then
        echo "创建数据库失败"
        return 1
    fi
    return 0
}

#删除数据库
del_db(){
    local project_name="$1"
    dbname=$(echo "$project_name" | sed 's/[^A-Za-z0-9_]/_/g')

    db_script_path
    if ! ./mysql_db_manager.sh delete "mysql" "$dbname"; then
        echo "删除数据库失败"
        return 1 
    fi
    return 0
}

# WARP脚本管理
warp_manage() {
    install wget
    wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash menu.sh [option] [lisence/url/token]
}

#工作区和系统工具路径
tool_script_path() {
    # 切换到一个一致的目录（例如，家目录）
    cd ~ || exit
    curl -O https://raw.githubusercontent.com/zxl2008gz/sh/main/system_tool_manage.sh
    chmod +x system_tool_manage.sh
}

#工作区域管理
work_area(){
    tool_script_path
    ./system_tool_manage.sh work
}

#系统工具管理
system_tool_manage(){
    tool_script_path
    export new_alias  # 将 new_alias 变量导出为环境变量
    ./system_tool_manage.sh tool
    if [ -n "$new_alias" ]; then
        kjjian=$new_alias
    fi
}

#安装LDNMP环境
install_ldnmp(){
    while true; do
        clear
        echo -e "${huang}LDNMP建站 ▶ ${bai}"
        echo "------------------------"
        echo "1. 安装LDNMP环境-Nginx(默认安装全部按回车)"
        echo "------------------------"				
        echo "2. 安装WordPress"
        echo "------------------------"
        echo "3. 安装可道云桌面               4. 安装独角数发卡网"
        echo "5. 安装flarum论坛网站"
        echo "------------------------"	
        echo "21. 安装epusdt收款地址          22. 安装LobeChat聊天网站" 
        echo "23. 安装GeminiPro聊天网站       24. 安装vaultwarden密码管理平台" 
        echo "25. onlyoffice在线办公OFFICE    26. Nextcloud网盘"
        echo "27. Speedtest测速服务面板       28. portainer容器管理面板"
        echo "29. Poste.io邮件服务器程序      30. 安装Halo博客网站"
        echo "31. QB离线BT磁力下载面板        32. VScode网页版"
        echo "33. UptimeKuma监控工具          34. Cloudreve网盘"
        echo "35. LibreSpeed测速工具          36. searxng聚合搜索站"
        echo "37. PhotoPrism私有相册系统      38. StirlingPDF工具大全"
        echo "39. drawio免费的在线图表软件"
        echo "------------------------"				
        echo "61. 仅安装nginx                62. 站点重定向"	
        echo "63. 站点反向代理-IP+端口        64. 站点反向代理-域名"
        echo "65. 自定义静态站点              66. 仅安装mysql"	
        echo "67. 仅安装PHP                  68. 仅安装redis"		
        echo "------------------------"	
        echo "81. 站点数据管理                82. 备份全站数据"		
        echo "83. 定时远程备份                84. 还原全站数据"					
        echo "------------------------"
        echo "85. 站点防御程序"		
        echo "------------------------"
        echo "86. 优化LDNMP环境               87. 更新LDNMP环境"									
        echo "88. 卸载LDNMP环境"					
        echo "------------------------"				
        echo "0. 返回主菜单"
        echo "------------------------"
        read -p "请输入你的选择: " sub_choice

        case $sub_choice in
            1)
                root_use
                ldnmp_install_status_one
                if check_port "443";then
                    install_dependency
                    if check_docker_installed; then
                        echo "Docker is installed."
                    else
                        update_docker
                    fi
                    install_certbot
                    panduan_swap
                    create_ldnmp_file                    
                    clear
                    echo "正在配置LDNMP环境，请耐心稍等……"
                    restart_customize_app "nginx"
                    install_php
                    clear
                    echo "LDNMP环境安装完毕"
                    echo "------------------------"
                    ldnmp_info
                    break_end
                else
                    echo "端口已被占用，请检查并释放该端口。"
                fi                
                ;;
            2)
                clear
                # wordpress
                webname="WordPress"
                ldnmp_install_status
                read ipv4_address ipv6_address < <(get_ip_address)
                add_yuming
                install_ssltls
                add_db "$yuming"
                wordpress_config
                restart_ldnmp
                wordpress_display "mysql"
                nginx_display "nginx"
                break_end
                ;;
            3)
                clear
                # kodbox
                webname="kodbox"
                ldnmp_install_status
                read ipv4_address ipv6_address < <(get_ip_address)
                add_yuming
                install_ssltls
                add_db "$yuming"
                kodbox_config
                restart_ldnmp
                kodbox_display "mysql"
                nginx_display "nginx"
                break_end
                ;;
            4)
                clear
                # dujiaoka
                webname="dujiaoka"
                ldnmp_install_status
                read ipv4_address ipv6_address < <(get_ip_address)
                add_yuming
                install_ssltls
                add_db "$yuming"
                dujiaoka_config
                restart_ldnmp
                dujiaoka_display "mysql"
                nginx_display "nginx"
                break_end
                ;;
            5)
                clear
                # flarum
                webname="flarum"
                ldnmp_install_status
                read ipv4_address ipv6_address < <(get_ip_address)
                add_yuming
                install_ssltls
                add_db "$yuming"
                flarum_config
                restart_ldnmp
                flarum_display "mysql"
                nginx_display "nginx"
                break_end
                ;;
            21)
                clear
                # epusdt
                webname="epusdt"
                ldnmp_install_status
                read ipv4_address ipv6_address < <(get_ip_address)
                add_yuming
                install_ssltls
                yuming_path
                install_epusdt "/home/docker/html/$yuming" "mysql"
                break_end
                ;;
            22)
                clear
                # LobeChat
                webname="LobeChat"
                ldnmp_install_status
                read ipv4_address ipv6_address < <(get_ip_address)
                add_yuming
                install_ssltls
                yuming_path
                install_lobe "mysql"
                break_end
                ;;
            23)
                clear
                # GeminiPro
                webname="GeminiPro"
                ldnmp_install_status
                read ipv4_address ipv6_address < <(get_ip_address)
                add_yuming
                install_ssltls
                yuming_path
                install_geminiPro
                break_end
                ;;
            24)
                clear
                # vaultwarden
                webname="vaultwarden"
                ldnmp_install_status
                read ipv4_address ipv6_address < <(get_ip_address)
                add_yuming
                install_ssltls
                yuming_path
                install_vaultwarden "/home/docker/html/$yuming"
                break_end
                ;;
            25)
                clear
                # onlyoffice
                webname="onlyoffice"
                ldnmp_install_status
                read ipv4_address ipv6_address < <(get_ip_address)
                add_yuming
                install_ssltls
                yuming_path
                install_onlyoffice "/home/docker/html/$yuming"
                break_end
                ;;  
            26)
                clear
                # nextcloud
                webname="nextcloud"
                ldnmp_install_status
                read ipv4_address ipv6_address < <(get_ip_address)
                add_yuming
                install_ssltls
                yuming_path
                install_nextcloud "/home/docker/html/$yuming" "mysql"
                break_end
                ;; 
            27)
                clear
                # speedtest
                webname="speedtest"
                ldnmp_install_status
                read ipv4_address ipv6_address < <(get_ip_address)
                add_yuming
                install_ssltls
                yuming_path
                install_speedtest
                break_end
                ;;  
            28)
                clear
                # portainer
                webname="portainer"
                ldnmp_install_status
                read ipv4_address ipv6_address < <(get_ip_address)
                add_yuming
                install_ssltls
                yuming_path
                install_portainer "/home/docker/html/$yuming"
                break_end
                ;;   
            29)
                clear
                # Poste
                webname="Poste"
                install_Poste
                break_end
                ;; 
            30)
                clear
                # halo
                webname="halo"
                ldnmp_install_status
                read ipv4_address ipv6_address < <(get_ip_address)
                add_yuming
                install_ssltls
                yuming_path
                install_halo "/home/docker/html/$yuming" "mysql"
                break_end
                ;;   
            31)
                clear
                # qbittorrent
                webname="qbittorrent"
                ldnmp_install_status
                read ipv4_address ipv6_address < <(get_ip_address)
                add_yuming
                install_ssltls
                yuming_path
                install_qbittorrent "/home/docker/html/$yuming"
                break_end
                ;;  
            32)
                clear
                # vscode
                webname="vscode"
                ldnmp_install_status
                read ipv4_address ipv6_address < <(get_ip_address)
                add_yuming
                install_ssltls
                yuming_path
                install_vscode_web "/home/docker/html/$yuming"
                break_end
                ;;
            33)
                clear
                # UptimeKuma
                webname="UptimeKuma"
                ldnmp_install_status
                read ipv4_address ipv6_address < <(get_ip_address)
                add_yuming
                install_ssltls
                yuming_path
                install_UptimeKuma "/home/docker/html/$yuming"
                break_end
                ;;   
            34)
                clear
                # cloudreve
                webname="cloudreve"
                ldnmp_install_status
                read ipv4_address ipv6_address < <(get_ip_address)
                add_yuming
                install_ssltls
                yuming_path
                install_cloudreve
                break_end
                ;;   
            35)
                clear
                # librespeed
                webname="librespeed"
                ldnmp_install_status
                read ipv4_address ipv6_address < <(get_ip_address)
                add_yuming
                install_ssltls
                yuming_path
                install_librespeed
                break_end
                ;; 
            36)
                clear
                # searxng
                webname="searxng"
                ldnmp_install_status
                read ipv4_address ipv6_address < <(get_ip_address)
                add_yuming
                install_ssltls
                yuming_path
                install_searxng "/home/docker/html/$yuming"
                break_end
                ;;   
            37)
                clear
                # photoprism
                webname="photoprism"
                ldnmp_install_status
                read ipv4_address ipv6_address < <(get_ip_address)
                add_yuming
                install_ssltls
                yuming_path
                install_photoprism "/home/docker/html/$yuming"
                break_end
                ;;
            38)
                clear
                # StirlingPDF
                webname="StirlingPDF"
                ldnmp_install_status
                read ipv4_address ipv6_address < <(get_ip_address)
                add_yuming
                install_ssltls
                yuming_path
                install_s_pdf "/home/docker/html/$yuming"
                break_end
                ;; 
            39)
                clear
                # drawio
                webname="drawio"
                ldnmp_install_status
                read ipv4_address ipv6_address < <(get_ip_address)
                add_yuming
                install_ssltls
                yuming_path
                install_drawio "/home/docker/html/$yuming"
                break_end
                ;;                          
            61)
                root_use
                if check_port "443";then
                    install_dependency
                    if check_docker_installed; then
                        echo "Docker is installed."
                    else
                        update_docker
                    fi
                    install_certbot
                    panduan_swap
                    install_nginx
                    nginx_display "nginx"                    
                else
                    echo "端口已被占用，请检查并释放该端口。"
                fi
                break_end
                ;;
            62)
                webname="站点重定向"
                nginx_install_status
                read ipv4_address ipv6_address < <(get_ip_address)
                add_yuming
                read -p "请输入跳转域名: " reverseproxy
                install_ssltls
                redirect_config
                nginx_status "mysql"
                break_end
                ;;
            63)
                webname="反向代理-IP+端口"
                nginx_install_status
                read ipv4_address ipv6_address < <(get_ip_address)
                add_yuming
                read -p "请输入你的反代IP: " reverseproxy
                read -p "请输入你的反代端口: " port
                install_ssltls
                reverseproxy_config
                nginx_status "mysql"
                break_end
                ;;
            64)
                webname="反向代理-域名"
                nginx_install_status
                read ipv4_address ipv6_address < <(get_ip_address)
                add_yuming
                echo -e "域名格式: ${huang}http://www.google.com${bai}"
                read -p "请输入你的反代域名: " fandai_yuming
                install_ssltls
                reverseproxy_domain
                nginx_status "mysql"
                break_end
                ;;
            65)
                webname="静态站点"
                nginx_install_status
                add_yuming
                install_ssltls
                custom_static
                nginx_status "mysql"
                break_end
                ;;
            66)
                clear
                root_use
                if check_docker_installed; then
                    echo "Docker is installed."
                else
                    update_docker
                fi
                install_db_mysql
                break_end
                ;;
            67) 
                clear
                root_use
                if check_docker_installed; then
                    echo "Docker is installed."
                else
                    update_docker
                fi
                install_php_php74
                clear
                echo "正在配置PHP环境，请耐心稍等……"
                install_php
                break_end
                ;;
            68)
                clear
                if check_docker_installed; then
                    echo "Docker is installed."
                else
                    update_dockers
                fi
                install_redis
                break_end
                ;;
            81)
                root_use
                site_manage "mysql"
                ;;
            82)
                clear
                cd /home/ && tar czvf web_$(date +"%Y%m%d%H%M%S").tar.gz web
                backup_site_data
                ;;
            83)
                scheduled_remote_backup
                ;;
            84)
                # 还原全站数据
                clear
                cd /home/ && ls -t /home/*.tar.gz | head -1 | xargs -I {} tar -xzf {}
                check_port "443"
                install_dependency
                if check_docker_installed; then
                    echo "Docker is installed."
                else
                    update_docker
                fi
                install_certbot
                clear
                echo "正在配置LDNMP环境，请耐心稍等……"
                restart_customize_app "nginx"
                install_php
                clear
                echo "LDNMP环境安装完毕"
                echo "------------------------"
                ldnmp_info
                break_end
                ;;
            85)
                site_defense_program
                ;;
            86)
                optimize_ldnmp
                ;;
            87)
                clear
                docker rm -f nginx php php74 mysql redis
                docker rmi nginx nginx:alpine php:fpm php:fpm-alpine php:7.4.33-fpm php:7.4-fpm-alpine mysql redis redis:alpine 
                if check_port "443";then
                    install_dependency
                    if check_docker_installed; then
                        echo "Docker is installed."
                    else
                        update_docker
                    fi
                    install_certbot
                    panduan_swap
                    create_ldnmp_file                    
                    clear
                    echo "正在配置LDNMP环境，请耐心稍等……"
                    restart_customize_app "nginx"
                    install_php
                    clear
                    echo "LDNMP环境安装完毕"
                    echo "------------------------"
                    ldnmp_info
                    break_end
                else
                    echo "端口已被占用，请检查并释放该端口。"
                fi             
                ;;
            88)
                clear
                read -p "强烈建议先备份全部网站数据，再卸载LDNMP环境。确定删除所有网站数据吗？(Y/N): " choice
                case "$choice" in
                    [Yy])
                        docker rm -f nginx php php74 mysql redis
                        docker rmi nginx nginx:alpine php:fpm php:fpm-alpine php:7.4.33-fpm php:7.4-fpm-alpine mysql redis redis:alpine
                        rm -rf /home/docker/web
                        break_end
                        ;;
                    [Nn])
                        break_end
                        ;;
                    *)
                        echo "无效的选择，请输入 Y 或 N。"
                        ;;
                esac
                ;;
            0)
                break
                ;;
            *)
                echo "无效的输入!"
        esac
    done
}

# 安装LDNMP环境-NginxProxyManager
panel_tools() {
    while true; do
        clear
        echo "▶ 安装LDNMP环境-NginxProxyManager"
        echo "------------------------"
        echo "1. NginxProxyManager可视化面板          2. mysql-redis-php容器"        
        echo "3. 安装LobeChat聊天网站                 4. 安装GeminiPro聊天网站"
        echo "5. 安装vaultwarden密码管理平台          6. 安装kodbox可道云网盘 "
        echo "7. drawio免费的在线图表软件             8. 安装dujiaoka独角数发卡网  "
        echo "9. 安装epusdt收款地址                  10. onlyoffice在线办公OFFICE "
        echo "11. Nextcloud网盘                     12. Speedtest测速服务面板 "
        echo "13. portainer容器管理面板              14. Poste.io邮件服务器程序 "  
        echo "15. 安装Halo博客网站                   16. QB离线BT磁力下载面板"    
        echo "17. VScode网页版                      18. UptimeKuma监控工具" 
        echo "19. Cloudreve网盘                     20. LibreSpeed测速工具" 
        echo "21. searxng聚合搜索站                 22. PhotoPrism私有相册系统"
        echo "23. StirlingPDF工具大全 "               
        echo "------------------------"
        echo "0. 返回主菜单"
        echo "------------------------"
        read -p "请输入你的选择: " sub_choice

        case $sub_choice in
            1)
                nginx-proxy-manager "/home/docker"
                ;;
            2)
                if check_docker_installed; then
                    echo "Docker is installed."
                else
                    update_docker
                fi
                install_mysql_redis_php
                install_php_php74
                clear
                echo "正在配置PHP环境，请耐心稍等……"
                install_php
                mysql_php_redis_info
                break_end                
                ;;
            3)  
                install_lobe "mysql"
                ;;
            4)
                install_geminiPro
                ;;
            5)
                install_vaultwarden "/home/docker"
                ;;
            6)
                install_kodbox "/home/docker" "mysql"
                ;;
            7)
                install_drawio "/home/docker"
                ;;
            8)
                install_dujiaoka "/home/docker" "mysql"
                ;;
            9)
                install_epusdt "/home/docker" "mysql"
                ;;
            10)
                install_onlyoffice "/home/docker"
                ;;
            11)
                install_nextcloud "/home/docker" "mysql"
                ;;
            12) 
                install_speedtest
                ;;
            13)
                install_portainer "/home/docker"
                ;;
            14)
                install_Poste
                ;;
            15)
                install_halo "/home/docker" "mysql"
                ;; 
            16)
                install_qbittorrent "/home/docker"
                ;;
            17)
                install_vscode_web "/home/docker"
                ;;  
            18)
                install_UptimeKuma "/home/docker"
                ;;   
            19)
                install_cloudreve
                ;; 
            20)
                install_librespeed
                ;;
            21)
                install_searxng "/home/docker"
                ;;
            22)
                install_photoprism "/home/docker"
                ;;
            23)
                install_s_pdf "/home/docker"
                ;;
            0)
                break  # 跳出循环，退出菜单
                ;;
            *)
                break  # 跳出循环，退出菜单
                ;;

        esac
        break_end
    done
}

# 主循环，用于显示菜单并处理用户输入
while true; do
    set_shortcut_keys   
    clear  # 清除屏幕
    # 显示菜单
    echo "_   _ "
    echo "|_  | |  |    | |\ | "
    echo " _| |_|  |___ | | \| "
    echo "                                "
    echo -e "${lianglan} solin一键脚本工具 v${vers} （支持Ubuntu/Debian/CentOS/Alpine系统）${bai}"
    echo -e "${lianglan}-输入${huang}${kjjian:-s}${lianglan}可快速启动此脚本-${bai}"
    echo "------------------------"
    echo "1. 系统信息查询"
    echo "2. 系统更新"
    echo "3. 系统清理"
    echo "4. 常用工具"
    echo "5. BBR管理 ▶"    
    echo "6. 测试脚本合集 ▶ "  
    echo "7. 甲骨文云脚本合集 ▶ "
    echo "8. 谷歌云脚本合集 ▶ "
    echo "9. Docker管理器 ▶ "  
    echo "10. MYSQL管理 ▶ "  
    echo "11. WARP管理 ▶ "    
    echo -e "${huang}12. LDNMP建站-Nginx ▶ ${bai}"
    echo -e "${huang}13. LDNMP建站-NginxProxyManager ▶ ${bai}"	
    echo "14. 我的工作区 ▶ "
    echo "15. 系统工具 ▶ "    
    echo "-----------------------"
    echo "00. 脚本更新"
    echo "------------------------"
    echo "0. 退出脚本"
    echo "------------------------"
    read -p "请输入你的选择: " choice
    case $choice in
        1)
            clear
            system_info_query
            break_end
            ;;
        2)
            clear
            update_service_info
            break_end
            ;; 
        3)
            clear
            clean_service_info
            break_end
            ;;
        4)
            clear
            common_tool_install
            break_end
            ;;        
        5)
            clear
            bbr_script
            break_end
            ;;        
        6)
            clear
            test_script
            break_end
            ;;
        7)
            clear
            oracle_script 
            break_end
            ;;
        8)
            clear
            gcp_script
            break_end
            ;;
        9)
            clear
            docker_manage
            ;;
        10)
            clear
            mysql_db_manage
            ;;
        11)
            clear
            warp_manage 
            ;;
        12)
            clear
            install_ldnmp 
            break_end
            ;;
        13)
            clear
            panel_tools
            break_end
            ;;
        14)
            clear
            work_area
            break_end
            ;; 
        15)            
            clear
            system_tool_manage
            break_end
            ;; 
        00)
            # 脚本更新逻辑
			echo ""
			curl -sS -O https://raw.githubusercontent.com/zxl2008gz/sh/main/solin.sh && chmod +x solin.sh
			echo "脚本已更新到最新版本！"
			break_end
			break
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
done    
