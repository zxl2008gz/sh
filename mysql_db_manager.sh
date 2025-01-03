#!/bin/bash

###################
# 颜色和常量定义  #
###################

# 颜色定义
readonly YELLOW='\033[33m'
readonly WHITE='\033[0m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly RED='\033[31m'
readonly CYAN='\033[96m'
readonly GRAY='\e[37m'

# 全局常量
readonly TIMEOUT_DURATION=20
readonly DEFAULT_MYSQL_PATH="/home/docker"
readonly DEFAULT_CONTAINER_NAME="mysql"
readonly DEFAULT_CONTAINER_IMAGE="mysql"
readonly DEFAULT_VOLUME_PATH="./mysql"
readonly DEFAULT_ROOT_PASSWORD="mysqlwebroot"
readonly DEFAULT_USER="mysqluse"
readonly DEFAULT_PASSWORD="mysqlpasswd"
readonly DEBUG_MODE=true  # 新增：调试模式开关
readonly MAX_BACKUP_COUNT=5  # 最大备份保留数量
readonly BACKUP_RETENTION_DAYS=30  # 备份保留天数
readonly PERFORMANCE_CHECK_INTERVAL=5  # 性能检查间隔(秒)

# 错误处理设置
set -o errexit
set -o nounset
set -o pipefail

###################
# 日志和调试函数  #
###################

# 调试信息输出
debug() {
    if [ "$DEBUG_MODE" = true ]; then
        echo -e "${CYAN}[调试]${WHITE} $1" >&2
    fi
}

# 日志输出函数
log_info() {
    echo -e "${GREEN}[信息]${WHITE} $1"
}

log_error() {
    echo -e "${RED}[错误]${WHITE} $1" >&2
    debug "错误堆栈: $(caller 0)"
}

log_warning() {
    echo -e "${YELLOW}[警告]${WHITE} $1"
}

# 错误处理函数
handle_error() {
    local error_code=$?
    local error_msg="$1"
    local error_line="${BASH_LINENO[0]}"
    local error_func="${FUNCNAME[1]}"
    
    log_error "错误: $error_msg"
    debug "错误代码: $error_code"
    debug "发生位置: $error_func:$error_line"
    
    # 记录错误到日志文件
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $error_msg (Code: $error_code) in $error_func:$error_line" >> /var/log/mysql_manager.log
    
    return $error_code
}

# 操作完成函数
break_end() {
    local message="${1:-操作已完成}"
    echo -e "${GREEN}${message}${WHITE}"
    echo "按任意键继续..."
    read -n 1 -s -r
    echo
    clear
}

# 用户确认函数
ask_confirmation() {
    local prompt="$1"
    local choice

    while true; do
        read -p "$prompt (Y/N): " choice
        case "${choice,,}" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) echo "无效的选择，请输入 Y 或 N。" ;;
        esac
    done
}

# 获取带超时的用户输入
get_user_input() {
    local prompt="$1"
    local default="$2"
    local timeout="$3"
    local input

    read -t "$timeout" -p "$prompt [默认: $default]: " input || true
    echo "${input:-$default}"
}

###################
# Docker检查函数  #
###################

# 检查Docker是否安装并运行
check_docker_installed() {
    if ! command -v docker &>/dev/null; then
        log_error "Docker 未安装"
        return 1
    fi

    if ! docker info &>/dev/null; then
        log_error "Docker 守护进程未运行"
        return 2
    fi

    # 检查并安装 docker-compose
    if ! command -v docker-compose &>/dev/null; then
        log_warning "docker-compose 未安装，正在安装..."
        # 检测包管理器
        if command -v apt &>/dev/null; then
            # 对于 Ubuntu/Debian 系统
            apt update && apt install -y docker-compose
        elif command -v yum &>/dev/null; then
            # 对于 CentOS/RHEL 系统
            yum install -y docker-compose
        elif command -v dnf &>/dev/null; then
            # 对于新版 CentOS/RHEL 系统
            dnf install -y docker-compose
        else
            # 如果没有找到包管理器，使用 curl 安装
            log_info "使用 curl 安装 docker-compose..."
            if ! curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose; then
                log_error "下载 docker-compose 失败"
                return 1
            fi
            chmod +x /usr/local/bin/docker-compose
        fi
        
        # 验证安装
        if ! command -v docker-compose &>/dev/null; then
            log_error "docker-compose 安装失败"
            return 1
        fi
        log_info "docker-compose 安装成功"
    fi

    debug "Docker 环境检查通过"
    return 0
}

# 检查容器是否运行
check_container_running() {
    local container_name="$1"
    
    if ! docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        log_error "容器 ${container_name} 未运行"
        debug "运行中的容器列表:"
        debug "$(docker ps)"
        return 1
    fi
    
    debug "容器 ${container_name} 正在运行"
    return 0
}

###################
# 系统工具函数    #
###################

# 安装软件包
install() {
    if [ $# -eq 0 ]; then
        log_error "未提供软件包参数！"
        return 1
    fi

    local package_manager
    if command -v dnf &>/dev/null; then
        package_manager="dnf"
    elif command -v yum &>/dev/null; then
        package_manager="yum"
    elif command -v apt &>/dev/null; then
        package_manager="apt"
    elif command -v apk &>/dev/null; then
        package_manager="apk"
    else
        log_error "未知的包管理器！"
        return 1
    fi

    debug "使用包管理器: $package_manager"

    for package in "$@"; do
        if ! command -v "$package" &>/dev/null; then
            log_info "正在安装 $package..."
            case $package_manager in
                dnf|yum)
                    $package_manager -y update && $package_manager install -y "$package"
                    ;;
                apt)
                    $package_manager update -y && $package_manager install -y "$package"
                    ;;
                apk)
                    $package_manager update && $package_manager add "$package"
                    ;;
            esac
        else
            log_info "$package 已经安装"
        fi
    done
}

# 卸载软件包
remove() {
    if [ $# -eq 0 ]; then
        log_error "未提供软件包参数！"
        return 1
    fi

    local package_manager
    if command -v dnf &>/dev/null; then
        package_manager="dnf"
    elif command -v yum &>/dev/null; then
        package_manager="yum"
    elif command -v apt &>/dev/null; then
        package_manager="apt"
    elif command -v apk &>/dev/null; then
        package_manager="apk"
    else
        log_error "未知的包管理器！"
        return 1
    fi

    debug "使用包管理器: $package_manager"

    for package in "$@"; do
        log_info "正在卸载 $package..."
        case $package_manager in
            dnf|yum)
                $package_manager remove -y "${package}*"
                ;;
            apt)
                $package_manager purge -y "${package}*"
                ;;
            apk)
                $package_manager del "${package}*"
                ;;
        esac
    done
}

# 函数:获取用户输入或默认数据,20秒后无输入则使用默认值,如果开始输入则等待完成
get_default_data_db() {
    local prompt="$1"
    local default_value="$2"
    local timeout="$3"
    local input=""
    local partial_input=""
    # 首次尝试读取输入,20秒超时
    read -t $timeout -p "$prompt (默认为:$default_value): " input || partial_input="$input"

    # 检查是否有部分输入
    if [ -n "$partial_input" ]; then
        # 如果有部分输入,继续读取直到完成
        input="$partial_input"
        while IFS= read -r -n1 -s char; do
            # 读取单个字符,没有超时
            input+="$char"
            # 检查是否是结束字符(回车)
            if [[ "$char" == $'\n' ]]; then
                break
            fi
        done
        # 从输入中移除最后的换行符
        input="${input%$'\n'}"
    elif [ -z "$input" ]; then
        # 超时无输入,使用默认值
        input="$default_value"
    fi

    echo "$input"
}

####################
# 安装更新MySQL环境 #
####################

#重置MySQL容器函数
reset_mysql_container() {
    local container_name="$1"
    local backup_path="$2"
    local dbroot_password="$3"
    
    # 检查是否存在旧容器
    if docker ps -a --format '{{.Names}}' | grep -Eq "^${container_name}\$"; then
        log_warning "检测到已存在的MySQL容器"
        
        # 尝试从多个位置获取旧密码
        local old_root_password=""
        
        # 1. 尝试从环境变量获取
        if docker ps --format '{{.Names}}' | grep -Eq "^${container_name}\$"; then
            old_root_password=$(docker exec "$container_name" printenv MYSQL_ROOT_PASSWORD 2>/dev/null || echo "")
        fi
        
        # 2. 尝试从 docker-compose 文件获取
        if [ -z "$old_root_password" ] && [ -f "/home/docker/docker-compose-mysql.yml" ]; then
            old_root_password=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/docker/docker-compose-mysql.yml | tr -d '[:space:]' || echo "")
        fi
        
        # 如果找到了旧密码，尝试备份
        if [ -n "$old_root_password" ]; then
            debug "尝试使用找到的旧密码进行备份"
            if docker ps --format '{{.Names}}' | grep -Eq "^${container_name}\$"; then
                if docker exec -e MYSQL_PWD="$old_root_password" "$container_name" mysql -u root -e "SELECT 1;" &>/dev/null; then
                    log_info "正在备份旧数据..."
                    backup_database "$container_name" "$backup_path" "$old_root_password" ""
                else
                    log_warning "无法使用旧密码连接到MySQL，跳过备份"
                fi
            fi
        fi

        # 停止并删除旧容器
        log_info "停止并删除旧容器..."
        docker stop "$container_name" >/dev/null 2>&1 || true
        docker rm "$container_name" >/dev/null 2>&1 || true
        
        # 可选：删除旧的数据卷
        if ask_confirmation "是否要删除旧的数据卷？这将永久删除所有数据"; then
            log_info "删除旧的数据卷..."
            docker volume rm "${container_name}_data" >/dev/null 2>&1 || true
            rm -rf "/home/docker/mysql" >/dev/null 2>&1 || true
        fi
    fi

    # 停止并删除现有容器
    if docker ps --format '{{.Names}}' | grep -Eq "^${container_name}\$"; then
        docker stop "$container_name" >/dev/null
        docker rm "$container_name" >/dev/null
    fi
}

update_mysql_env() {
    local db_mysql_path=$(get_default_data_db "请输入MySQL的路径" "/home/docker" "$TIMEOUT_DURATION")
    local mysql_container_name=$(get_default_data_db "请输入MySQL的容器名" "$DEFAULT_CONTAINER_NAME" "$TIMEOUT_DURATION")
    local mysql_container_image=$(get_default_data_db "请输入MySQL的镜像名" "$DEFAULT_CONTAINER_IMAGE" "$TIMEOUT_DURATION")
    local mysql_container_volume=$(get_default_data_db "请输入持久化volume路径" "$DEFAULT_VOLUME_PATH" "$TIMEOUT_DURATION")
    local mysql_container_rootwd=$(get_default_data_db "请设置MySQL容器的root密码" "$DEFAULT_ROOT_PASSWORD" "$TIMEOUT_DURATION")
    local mysql_container_dbuse=$(get_default_data_db "请设置MySQL容器的用户名" "$DEFAULT_USER" "$TIMEOUT_DURATION")
    local mysql_container_passwd=$(get_default_data_db "请设置MySQL容器的用户密码" "$DEFAULT_PASSWORD" "$TIMEOUT_DURATION")
    # 创建必要的目录和文件  
    mkdir -p "$db_mysql_path" && cd "$db_mysql_path"
    mkdir -p mysql mysql_backup
    touch docker-compose-mysql.yml

    install openssl

    # 判断是否使用了默认密码,并在是的情况下生成新的随机密码
    if [[ "$mysql_container_rootwd" == "$DEFAULT_ROOT_PASSWORD" ]]; then
        log_info "使用默认root密码,正在生成新的随机密码..."
        mysql_container_rootwd=$(openssl rand -base64 16)
        log_info "新的root密码: $mysql_container_rootwd"
    fi

    if [[ "$mysql_container_dbuse" == "$DEFAULT_USER" ]]; then
        log_info "使用默认用户名,正在生成新的随机用户名..."
        mysql_container_dbuse=$(openssl rand -hex 4)
        log_info "新的用户名: $mysql_container_dbuse"
    fi

    if [[ "$mysql_container_passwd" == "$DEFAULT_PASSWORD" ]]; then
        log_info "使用默认用户密码,正在生成新的随机密码..."
        mysql_container_passwd=$(openssl rand -base64 8)
        log_info "新的用户密码: $mysql_container_passwd"
    fi

    # 下载并应用 docker-compose 配置
    if ! wget -O "$db_mysql_path/docker-compose-mysql.yml" https://raw.githubusercontent.com/zxl2008gz/docker/main/LDNMP/docker-compose-mysql.yml; then
        log_error "下载 docker-compose.yml 文件失败"
        return 1
    fi

    # 在 docker-compose.yml 文件中进行替换  
    sed -i "s|mysqlwebroot|$mysql_container_rootwd|g" "$db_mysql_path/docker-compose-mysql.yml"
    sed -i "s|mysqlpasswd|$mysql_container_passwd|g" "$db_mysql_path/docker-compose-mysql.yml" 
    sed -i "s|mysqluse|$mysql_container_dbuse|g" "$db_mysql_path/docker-compose-mysql.yml"

    local dbroot_password=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' "$db_mysql_path/docker-compose-mysql.yml" | tr -d '[:space:]')

    reset_mysql_container "$mysql_container_name" "$db_mysql_path/mysql_backup" "$dbroot_password"

    # 使用 docker-compose 启动容器，添加错误处理
    cd "$db_mysql_path"
    if ! docker-compose -f docker-compose-mysql.yml up -d; then
        log_error "启动 MySQL 容器失败"
        # 尝试使用 docker run 作为备选方案
        log_info "尝试使用 docker run 启动容器..."
        if ! docker run -d \
            --name "$mysql_container_name" \
            -e MYSQL_ROOT_PASSWORD="$mysql_container_rootwd" \
            -e MYSQL_USER="$mysql_container_dbuse" \
            -e MYSQL_PASSWORD="$mysql_container_passwd" \
            -v "$mysql_container_volume:/var/lib/mysql" \
            "$mysql_container_image"; then
            log_error "使用 docker run 启动容器也失败"
            return 1
        fi
        log_info "使用 docker run 启动容器成功"
    else
        log_info "使用 docker-compose 启动容器成功"
    fi

    # 等待 MySQL 服务就绪
    log_info "等待 MySQL 服务就绪..."
    local max_attempts=30
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if docker exec "$mysql_container_name" mysqladmin -u root -p"$mysql_container_rootwd" ping &>/dev/null; then
            log_info "MySQL 服务已就绪"
            break
        fi
        log_info "等待 MySQL 初始化... ($attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done

    if [ $attempt -gt $max_attempts ]; then
        log_error "MySQL 服务启动超时"
        return 1
    fi

    log_info "MySQL环境安装/更新完成"
    echo "安装信息如下:"  
    echo "新的用户名: $mysql_container_dbuse"
    echo "新的用户密码: $mysql_container_passwd"  
    echo "新的root密码: $mysql_container_rootwd"

    break_end
}


###################
# 数据库核心操作  #
###################

# 获取数据库容器名称
get_db_container_name() {
    local search_term="$1"
    local container_name

    debug "查找MySQL容器，搜索条件: $search_term"
    
    # 先尝试精确匹配
    container_name=$(docker ps --format "{{.Names}}" | grep "^${search_term}$")
    
    # 如果没找到，尝试部分匹配
    if [ -z "$container_name" ]; then
        debug "未找到精确匹配，尝试部分匹配..."
        # 尝试查找包含 mysql 的容器
        container_name=$(docker ps --format "{{.Names}}\t{{.Image}}" | grep -i "mysql" | head -n 1 | awk '{print $1}')
    fi

    if [ -z "$container_name" ]; then
        log_error "未找到运行中的MySQL容器"
        debug "运行中的容器列表:"
        debug "$(docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}')"
        return 1
    fi

    debug "找到MySQL容器: $container_name"
    echo "$container_name"
}

# 获取容器环境变量值
get_config_value() {
    local var_name="$1"
    local container_name="$2"
    local value

    debug "从容器 $container_name 获取变量 $var_name"
    
    if ! value=$(docker exec "$container_name" /bin/sh -c "echo \${$var_name}" 2>/dev/null); then
        log_error "无法从容器获取配置值"
        debug "容器状态: $(docker inspect --format '{{.State.Status}}' "$container_name")"
        return 1
    fi

    debug "获取到的值: $value"
    echo "$value"
}

# 获取数据库凭据
get_db_credentials() {
    local container_name="$1"
    local user password root_password
    
    debug "开始获取数据库凭据"

    # 检查容器是否运行
    if ! check_container_running "$container_name"; then
        log_error "容器未运行，无法获取凭据"
        return 1
    fi

    # 获取root密码
    root_password=$(get_config_value 'MYSQL_ROOT_PASSWORD' "$container_name")
    if [ -z "$root_password" ]; then
        log_error "无法获取MySQL root密码"
        debug "尝试从默认位置读取密码..."
        # 尝试从docker-compose文件读取默认密码
        if [ -f "/home/docker/docker-compose-mysql.yml" ]; then
            root_password=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/docker/docker-compose-mysql.yml | tr -d '[:space:]')
        fi
        if [ -z "$root_password" ]; then
            log_error "无法获取任何可用的root密码"
            return 1
        fi
    fi

    # 获取普通用户凭据
    user=$(get_config_value 'MYSQL_USER' "$container_name")
    password=$(get_config_value 'MYSQL_PASSWORD' "$container_name")

    # 如果普通用户凭据为空，使用root凭据
    [ -z "$user" ] && user="root"
    [ -z "$password" ] && password="$root_password"

    debug "凭据获取成功"
    echo "$user $password $root_password"
}

# 检查MySQL连接
check_mysql_connection() {
    local container_name="$1"
    local password="$2"
    
    debug "测试MySQL连接"

    # 尝试多次连接
    local max_attempts=5
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if docker exec -e MYSQL_PWD="$password" "$container_name" \
            mysql -u root --execute="SELECT 1;" &>/dev/null; then
            debug "MySQL连接测试成功"
            return 0
        fi
        debug "连接尝试 $attempt/$max_attempts 失败，等待重试..."
        sleep 2
        ((attempt++))
    done

    log_error "无法连接到MySQL服务器"
    debug "MySQL状态: $(docker exec "$container_name" mysqladmin -u root -p"$password" status 2>&1)"
    return 1
}

# 检查数据库是否存在
database_exists() {
    local container_name="$1"
    local dbname="$2"
    local dbroot_password="$3"

    debug "检查数据库是否存在: $dbname"

    # 首先检查MySQL连接
    if ! check_mysql_connection "$container_name" "$dbroot_password"; then
        return 1
    fi

    local check_command="SHOW DATABASES LIKE '$dbname';"
    if docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root -e "$check_command" 2>/dev/null | grep -q "$dbname"; then
        debug "数据库 $dbname 已存在"
        return 0
    else
        debug "数据库 $dbname 不存在"
        return 1
    fi
}

# 创建数据库并授权
create_database_and_grant() {
    local container_name="$1"
    local dbname="$2"
    local dbuser="$3"
    local dbuser_password="$4"
    local dbroot_password="$5"

    debug "开始创建数据库: $dbname"

    # 检查MySQL连接
    if ! check_mysql_connection "$container_name" "$dbroot_password"; then
        return 1
    fi

    # 验证数据库名称
    if [[ ! "$dbname" =~ ^[a-zA-Z0-9_]+$ ]]; then
        log_error "无效的数据库名称: $dbname"
        return 1
    fi

    # 检查数据库是否已存在
    if database_exists "$container_name" "$dbname" "$dbroot_password"; then
        if ask_confirmation "数据库 '$dbname' 已存在。是否重建？"; then
            log_info "删除现有数据库..."
            if ! docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root -e "DROP DATABASE \`$dbname\`;" 2>/dev/null; then
                log_error "删除数据库失败"
                return 1
            fi
        else
            log_info "操作已取消"
            return 0
        fi
    fi

    # 创建数据库
    log_info "创建数据库 $dbname..."
    local create_db_command="CREATE DATABASE IF NOT EXISTS \`${dbname}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    if ! docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root -e "$create_db_command" 2>/dev/null; then
        log_error "创建数据库失败"
        return 1
    fi

    # 创建用户并授权
    log_info "设置用户权限..."
    local grant_command="CREATE USER IF NOT EXISTS '${dbuser}'@'%' IDENTIFIED BY '${dbuser_password}';"
    grant_command+=" GRANT ALL PRIVILEGES ON \`${dbname}\`.* TO '${dbuser}'@'%';"
    grant_command+=" FLUSH PRIVILEGES;"

    if ! docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root -e "$grant_command" 2>/dev/null; then
        log_error "设置权限失败"
        return 1
    fi

    log_info "数据库 '$dbname' 创建成功，并已授权给用户 '$dbuser'"
    return 0
}

# 验证数据库名称
validate_database_name() {
    local dbname="$1"
    if [[ ! "$dbname" =~ ^[a-zA-Z0-9_]+$ ]]; then
        log_error "无效的数据库名称。只允许使用字母、数字和下划线。"
        return 1
    fi
    return 0
}

###################
# 数据库操作功能  #
###################

# 查询数据库并列出所有表
query_database() {
    local container_name=$1
    local dbroot_password=$2
    local dbname=$3

    debug "查询数据库: $dbname"

    # 检查数据库是否存在
    if ! database_exists "$container_name" "$dbname" "$dbroot_password"; then
        log_error "数据库 '$dbname' 不存在"
        return 1
    fi

    local query="SELECT 
        TABLE_NAME as '表名', 
        TABLE_ROWS as '行数',
        ROUND((DATA_LENGTH + INDEX_LENGTH)/1024/1024, 2) as '大小(MB)',
        CREATE_TIME as '创建时间',
        UPDATE_TIME as '更新时间'
    FROM information_schema.tables 
    WHERE TABLE_SCHEMA = '$dbname'
    ORDER BY TABLE_NAME;"

    if ! output=$(docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root -e "$query" "$dbname" 2>&1); then
        log_error "查询数据库失败: $output"
        return 1
    fi
    
    clear
    echo -e "${BLUE}数据库 '$dbname' 的表信息：${WHITE}"
    echo "---------------------------------------------"
    echo "$output"
    echo "---------------------------------------------"
}

# 导入数据库
import_database() {
    local container_name=$1
    local dbname=$2
    local dbroot_password=$3
    local datafile=$4

    debug "导入数据库文件: $datafile 到 $dbname"

    # 检查文件是否存在
    if [ ! -f "$datafile" ]; then
        log_error "数据文件不存在: $datafile"
        return 1
    fi

    # 检查文件格式
    if [[ ! "$datafile" =~ \.(sql|gz|bz2)$ ]]; then
        log_error "不支持的文件格式。请使用 .sql, .gz 或 .bz2 文件"
        return 1
    fi

    # 确保数据库存在
    if ! database_exists "$container_name" "$dbname" "$dbroot_password"; then
        log_info "数据库 '$dbname' 不存在，正在创建..."
        if ! docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root -e "CREATE DATABASE \`$dbname\`;" 2>/dev/null; then
            log_error "创建数据库失败"
            return 1
        fi
    fi

    log_info "开始导入数据..."
    case "$datafile" in
        *.gz)
            if ! zcat "$datafile" | docker exec -i -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root "$dbname"; then
                log_error "导入压缩数据失败"
                return 1
            fi
            ;;
        *.bz2)
            if ! bzcat "$datafile" | docker exec -i -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root "$dbname"; then
                log_error "导入压缩数据失败"
                return 1
            fi
            ;;
        *.sql)
            if ! docker exec -i -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root "$dbname" < "$datafile"; then
                log_error "导入数据失败"
                return 1
            fi
            ;;
    esac

    log_info "数据成功导入到数据库 '$dbname'"
    return 0
}

# 删除数据库并撤销权限
delete_database() {
    local container_name="$1"
    local dbname="$2"
    local dbroot_password="$3"
    local dbuser="$4"

    debug "开始删除数据库: $dbname"

    # 检查MySQL连接
    if ! check_mysql_connection "$container_name" "$dbroot_password"; then
        return 1
    fi

    # 检查系统数据库
    local system_dbs=("information_schema" "mysql" "performance_schema" "sys")
    if [[ " ${system_dbs[@]} " =~ " ${dbname} " ]]; then
        log_error "不能删除系统数据库: $dbname"
        return 1
    fi

    # 检查数据库是否存在
    if ! database_exists "$container_name" "$dbname" "$dbroot_password"; then
        log_error "数据库 '$dbname' 不存在"
        return 1
    fi

    log_info "正在删除数据库..."
    
    # 删除数据库
    local drop_db_command="DROP DATABASE IF EXISTS \`${dbname}\`;"
    if ! docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" \
        mysql -u root -e "$drop_db_command" 2>/dev/null; then
        log_error "删除数据库失败"
        return 1
    fi

    # 撤销用户权限
    if [ -n "$dbuser" ]; then
        log_info "正在撤销用户权限..."
        local revoke_command="REVOKE ALL PRIVILEGES ON \`${dbname}\`.* FROM '${dbuser}'@'%';"
        revoke_command+=" FLUSH PRIVILEGES;"

        if ! docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" \
            mysql -u root -e "$revoke_command" 2>/dev/null; then
            log_warning "撤销权限失败，但数据库已删除"
        fi
    fi

    log_info "数据库 '$dbname' 已成功删除"
    return 0
}

# 重命名数据库函数
rename_database() {
    local container_name="$1"
    local old_dbname="$2"
    local new_dbname="$3"
    local dbroot_password="$4"
    
    debug "开始重命名数据库: $old_dbname -> $new_dbname"
    
    # 检查是否是系统数据库
    local system_dbs=("mysql" "information_schema" "performance_schema" "sys")
    for sys_db in "${system_dbs[@]}"; do
        if [ "$old_dbname" = "$sys_db" ]; then
            log_error "不能重命名系统数据库 '$old_dbname'"
            return 1
        fi
    done

    # 检查MySQL连接
    if ! check_mysql_connection "$container_name" "$dbroot_password"; then
        return 1
    fi

    # 检查源数据库是否存在
    if ! database_exists "$container_name" "$old_dbname" "$dbroot_password"; then
        log_error "源数据库 '$old_dbname' 不存在"
        return 1
    fi

    # 检查目标数据库是否已存在
    if database_exists "$container_name" "$new_dbname" "$dbroot_password"; then
        log_error "目标数据库 '$new_dbname' 已存在"
        return 1
    fi

    log_info "正在重命名数据库..."

    # 创建新数据库
    if ! docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" \
        mysql -u root -e "CREATE DATABASE \`$new_dbname\`"; then
        log_error "创建新数据库失败"
        return 1
    fi

    # 获取所有表
    local tables
    tables=$(docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" \
        mysql -u root -N -e "SHOW TABLES FROM \`$old_dbname\`")

    # 移动每个表
    for table in $tables; do
        log_info "移动表: $table"
        if ! docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" \
            mysql -u root -e "RENAME TABLE \`$old_dbname\`.\`$table\` TO \`$new_dbname\`.\`$table\`"; then
            log_error "移动表 $table 失败"
            # 回滚操作
            log_warning "正在回滚更改..."
            # 将已移动的表移回原数据库
            docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" \
                mysql -u root -e "
                SELECT CONCAT('RENAME TABLE \`$new_dbname\`.\`', table_name, '\` TO \`$old_dbname\`.\`', table_name, '\`;')
                FROM information_schema.tables 
                WHERE table_schema = '$new_dbname';" | \
            while read -r rename_cmd; do
                docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" \
                    mysql -u root -e "$rename_cmd" || true
            done
            # 删除新创建的空数据库
            docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" \
                mysql -u root -e "DROP DATABASE IF EXISTS \`$new_dbname\`"
            return 1
        fi
    done

    # 删除旧数据库
    if ! docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" \
        mysql -u root -e "DROP DATABASE \`$old_dbname\`"; then
        log_error "删除旧数据库失败"
        return 1
    fi

    log_info "数据库重命名成功"
    return 0
}

# 数据库列表显示
mysql_display() {
    local container_name1="$1"
    local credentials1="${2:-}"  # 如果参数未提供，使用空字符串
    
    debug "获取数据库列表"

    echo -e "${BLUE}可用的数据库容器:${WHITE}"
    echo "---------------------------------------------"
    printf "%-30s %-20s\n" "数据库列表" "容器名称"
    echo "---------------------------------------------"

    local container_list
    container_list=$(docker ps --format "{{.Names}}\t{{.Image}}" | grep "$container_name1") || {
        log_error "无法获取容器列表"
        return 1
    }

    if [ -z "$container_list" ]; then
        log_warning "没有找到匹配的MySQL容器"
        return 1
    fi

    # 如果没有提供凭据，尝试获取
    if [ -z "$credentials1" ]; then
        local temp_creds
        if ! temp_creds=($(get_db_credentials "$container_name1")); then
            log_error "无法获取数据库凭据"
            return 1
        fi
        credentials1="${temp_creds[2]}"
    fi

    echo "$container_list" | while read -r container_name image_name; do
        if ! check_mysql_connection "$container_name" "$credentials1"; then
            log_warning "容器 $container_name 的MySQL服务不可访问"
            continue
        fi

        local databases
        databases=$(docker exec -e MYSQL_PWD="$credentials1" "$container_name" mysql -u root -e 'SHOW DATABASES;' | sed '1d')
        
        if [ -n "$databases" ]; then
            while read -r db; do
                # 获取数据库大小
                local size
                size=$(docker exec -e MYSQL_PWD="$credentials1" "$container_name" mysql -u root -e "
                    SELECT ROUND(SUM(data_length + index_length)/1024/1024, 2)
                    FROM information_schema.tables
                    WHERE table_schema='$db'
                    GROUP BY table_schema;" | sed '1d')
                
                # 如果大小为空，设为0
                size=${size:-0}
                
                printf "%-25s %-20s %8.2f MB\n" "$db" "$container_name" "$size"
            done <<< "$databases"
        else
            log_warning "容器 $container_name 中没有找到数据库"
        fi
    done
    echo "---------------------------------------------"
}

# 优化数据库表函数
optimize_tables() {
    local container_name="$1"
    local dbname="$2"
    local dbroot_password="$3"
    local table_name="$4"
    
    debug "开始优化表"
    
    # 获取要优化的表列表
    local tables
    if [ "$table_name" = "all" ]; then
        tables=$(docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root \
            -N -e "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA='$dbname';")
    else
        tables="$table_name"
    fi

    # 逐个优化表
    for table in $tables; do
        log_info "正在优化表: $table"
        if ! docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root \
            -e "OPTIMIZE TABLE \`$dbname\`.\`$table\`;" 2>/dev/null; then
            log_warning "优化表 $table 时出现警告，尝试使用 ANALYZE TABLE"
            docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root \
                -e "ANALYZE TABLE \`$dbname\`.\`$table\`;" 2>/dev/null || true
        fi
    done

    log_info "表优化完成"
}

# 管理数据库表函数
manage_tables() {
    local container_name="$1"
    local dbname="$2"
    local dbroot_password="$3"
    
    while true; do
        clear
        echo -e "${BLUE}表管理 - 数据库: $dbname${WHITE}"
        echo "---------------------------------------------"
        echo "表信息:"
        echo "表名    行数    大小(MB)        创建时间        更新时间"
        
        # 获取表信息
        docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root -N -e "
            SELECT 
                TABLE_NAME,
                TABLE_ROWS,
                ROUND(DATA_LENGTH/1024/1024, 2),
                CREATE_TIME,
                UPDATE_TIME
            FROM information_schema.TABLES 
            WHERE TABLE_SCHEMA='$dbname'
            ORDER BY TABLE_NAME;" | \
        while read -r name rows size create update; do
            printf "%-8s %-8s %-12s %-16s %-16s\n" \
                "${name:-'-'}" "${rows:-0}" "${size:-0.00}" \
                "${create:-NULL}" "${update:-NULL}"
        done
        
        echo "---------------------------------------------"
        echo "操作选项:"
        echo "1. 优化表"
        echo "2. 修复表"
        echo "3. 查看表结构"
        echo "4. 修改表结构"
        echo "5. 清空表数据"
        echo "6. 复制表"
        echo "7. 重命名表"
        echo "8. 导出表数据"
        echo "9. 导入表数据"
        echo "0. 返回上级菜单"
        echo "---------------------------------------------"
        read -p "请选择操作: " option
        
        case $option in
            1)  # 优化表
                read -p "请输入表名(all表示所有表): " table_name
                if [ -n "$table_name" ]; then
                    optimize_tables "$container_name" "$dbname" "$dbroot_password" "$table_name"
                else
                    log_error "表名不能为空"
                fi
                break_end
                ;;
            2)  # 修复表
                read -p "请输入表名(all表示所有表): " table_name
                if [ -n "$table_name" ]; then
                    repair_tables "$container_name" "$dbname" "$dbroot_password" "$table_name"
                else
                    log_error "表名不能为空"
                fi
                break_end
                ;;
            3)  # 查看表结构
                read -p "请输入表名: " table_name
                if [ -n "$table_name" ]; then
                    show_table_structure "$container_name" "$dbname" "$dbroot_password" "$table_name"
                else
                    log_error "表名不能为空"
                fi
                break_end
                ;;
            4)  # 修改表结构
                read -p "请输入表名: " table_name
                if [ -n "$table_name" ]; then
                    alter_table_structure "$container_name" "$dbname" "$dbroot_password" "$table_name"
                else
                    log_error "表名不能为空"
                fi
                break_end
                ;;
            5)  # 清空表数据
                read -p "请输入表名: " table_name
                if [ -n "$table_name" ]; then
                    if ask_confirmation "确定要清空表 '$table_name' 的所有数据吗？此操作不可恢复"; then
                        truncate_table "$container_name" "$dbname" "$dbroot_password" "$table_name"
                    fi
                else
                    log_error "表名不能为空"
                fi
                break_end
                ;;
            6)  # 复制表
                read -p "请输入源表名: " src_table
                read -p "请输入目标表名: " dst_table
                if [ -n "$src_table" ] && [ -n "$dst_table" ]; then
                    copy_table "$container_name" "$dbname" "$dbroot_password" "$src_table" "$dst_table"
                else
                    log_error "表名不能为空"
                fi
                break_end
                ;;
            7)  # 重命名表
                read -p "请输入当前表名: " old_table
                read -p "请输入新表名: " new_table
                if [ -n "$old_table" ] && [ -n "$new_table" ]; then
                    rename_table "$container_name" "$dbname" "$dbroot_password" "$old_table" "$new_table"
                else
                    log_error "表名不能为空"
                fi
                break_end
                ;;
            8)  # 导出表数据
                read -p "请输入表名: " table_name
                read -p "请输入导出文件路径: " export_path
                if [ -n "$table_name" ] && [ -n "$export_path" ]; then
                    export_table_data "$container_name" "$dbname" "$dbroot_password" "$table_name" "$export_path"
                else
                    log_error "表名和文件路径不能为空"
                fi
                break_end
                ;;
            9)  # 导入表数据
                read -p "请输入表名: " table_name
                read -p "请输入导入文件路径: " import_path
                if [ -n "$table_name" ] && [ -n "$import_path" ]; then
                    import_table_data "$container_name" "$dbname" "$dbroot_password" "$table_name" "$import_path"
                else
                    log_error "表名和文件路径不能为空"
                fi
                break_end
                ;;
            0)
                break
                ;;
            *)
                log_error "无效的选择"
                break_end
                ;;
        esac
    done
}

# 添加新的表管理函数
repair_tables() {
    local container_name="$1"
    local dbname="$2"
    local dbroot_password="$3"
    local table_name="$4"
    
    if [ "$table_name" = "all" ]; then
        log_info "修复所有表..."
        docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root -e "
            SELECT CONCAT('REPAIR TABLE \`$dbname\`.\`', TABLE_NAME, '\`;')
            FROM information_schema.TABLES 
            WHERE TABLE_SCHEMA='$dbname';" | \
        while read -r repair_cmd; do
            log_info "执行: $repair_cmd"
            docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" \
                mysql -u root -e "$repair_cmd"
        done
    else
        log_info "修复表: $table_name"
        docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" \
            mysql -u root -e "REPAIR TABLE \`$dbname\`.\`$table_name\`;"
    fi
}

show_table_structure() {
    local container_name="$1"
    local dbname="$2"
    local dbroot_password="$3"
    local table_name="$4"
    
    echo -e "${BLUE}表 $table_name 的结构:${WHITE}"
    echo "---------------------------------------------"
    
    # 获取表结构信息
    local table_info
    table_info=$(docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" \
        mysql -u root -N -e "
        SELECT 
            COLUMN_NAME as '字段名',
            COLUMN_TYPE as '数据类型',
            IS_NULLABLE as '允许空',
            COLUMN_DEFAULT as '默认值',
            COLUMN_KEY as '键类型',
            EXTRA as '额外信息'
        FROM information_schema.COLUMNS 
        WHERE TABLE_SCHEMA='$dbname' 
        AND TABLE_NAME='$table_name'
        ORDER BY ORDINAL_POSITION;")
    
    # 打印表头
    printf "%-20s %-20s %-10s %-15s %-10s %-20s\n" \
        "字段名" "数据类型" "允许空" "默认值" "键类型" "额外信息"
    echo "---------------------------------------------"
    
    # 打印表结构
    echo "$table_info" | while read -r col_name col_type nullable default key extra; do
        printf "%-20s %-20s %-10s %-15s %-10s %-20s\n" \
            "${col_name:--}" \
            "${col_type:--}" \
            "${nullable:--}" \
            "${default:--}" \
            "${key:--}" \
            "${extra:--}"
    done
    
    # 获取并显示表的其他信息
    echo -e "\n${YELLOW}表信息:${WHITE}"
    echo "---------------------------------------------"
    docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" \
        mysql -u root -N -e "
        SELECT 
            CONCAT('存储引擎: ', ENGINE),
            CONCAT('行数: ', TABLE_ROWS),
            CONCAT('数据大小: ', ROUND(DATA_LENGTH/1024/1024, 2), ' MB'),
            CONCAT('索引大小: ', ROUND(INDEX_LENGTH/1024/1024, 2), ' MB'),
            CONCAT('创建时间: ', CREATE_TIME),
            CONCAT('更新时间: ', COALESCE(UPDATE_TIME, 'NULL'))
        FROM information_schema.TABLES 
        WHERE TABLE_SCHEMA='$dbname' 
        AND TABLE_NAME='$table_name';" | \
    while read -r info; do
        echo "$info"
    done
    
    # 获取并显示索引信息
    echo -e "\n${YELLOW}索引信息:${WHITE}"
    echo "---------------------------------------------"
    docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" \
        mysql -u root -N -e "SHOW INDEX FROM \`$dbname\`.\`$table_name\`;" | \
    awk 'BEGIN {
        printf "%-15s %-15s %-10s %-15s %-10s\n", 
        "索引名", "列名", "唯一性", "可空", "类型"
    }
    {
        printf "%-15s %-15s %-10s %-15s %-10s\n",
        $3, $5, ($3=="PRIMARY"?"是":"否"), 
        ($10=="YES"?"是":"否"), $11
    }'
}

alter_table_structure() {
    local container_name="$1"
    local dbname="$2"
    local dbroot_password="$3"
    local table_name="$4"
    
    echo "当前表结构:"
    show_table_structure "$container_name" "$dbname" "$dbroot_password" "$table_name"
    
    echo "请输入ALTER TABLE语句(例如: ADD COLUMN new_col INT):"
    read -p "> " alter_statement
    
    if [ -n "$alter_statement" ]; then
        if ask_confirmation "确定要修改表结构吗？"; then
            docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" \
                mysql -u root -e "ALTER TABLE \`$dbname\`.\`$table_name\` $alter_statement;"
            log_info "表结构修改成功"
        fi
    else
        log_error "ALTER语句不能为空"
    fi
}

truncate_table() {
    local container_name="$1"
    local dbname="$2"
    local dbroot_password="$3"
    local table_name="$4"
    
    docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" \
        mysql -u root -e "TRUNCATE TABLE \`$dbname\`.\`$table_name\`;"
    log_info "表 $table_name 已清空"
}

copy_table() {
    local container_name="$1"
    local dbname="$2"
    local dbroot_password="$3"
    local src_table="$4"
    local dst_table="$5"
    
    docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root -e "
        CREATE TABLE \`$dbname\`.\`$dst_table\` LIKE \`$dbname\`.\`$src_table\`;
        INSERT INTO \`$dbname\`.\`$dst_table\` SELECT * FROM \`$dbname\`.\`$src_table\`;"
    log_info "表复制完成"
}

rename_table() {
    local container_name="$1"
    local dbname="$2"
    local dbroot_password="$3"
    local old_table="$4"
    local new_table="$5"
    
    docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" \
        mysql -u root -e "RENAME TABLE \`$dbname\`.\`$old_table\` TO \`$dbname\`.\`$new_table\`;"
    log_info "表重命名完成"
}

export_table_data() {
    local container_name="$1"
    local dbname="$2"
    local dbroot_password="$3"
    local table_name="$4"
    local export_path="$5"
    
    docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" \
        mysqldump -u root "$dbname" "$table_name" > "$export_path"
    log_info "表数据导出完成: $export_path"
}

import_table_data() {
    local container_name="$1"
    local dbname="$2"
    local dbroot_password="$3"
    local table_name="$4"
    local import_path="$5"
    
    if [ ! -f "$import_path" ]; then
        log_error "导入文件不存在"
        return 1
    fi
    
    docker exec -i -e MYSQL_PWD="$dbroot_password" "$container_name" \
        mysql -u root "$dbname" < "$import_path"
    log_info "表数据导入完成"
}

###################
# 容器管理功能    #
###################

# 监控MySQL状态
monitor_mysql_status() {
    local container_name=$1
    local dbroot_password=$2
    
    debug "开始监控MySQL状态"
    
    # 检查容器状态
    if ! check_container_running "$container_name"; then
        log_error "MySQL容器未运行"
        return 1
    fi

    trap 'echo -e "\n${YELLOW}退出监控...${WHITE}"; return 0' INT
    
    while true; do
        clear
        echo -e "${BLUE}MySQL状态监控${WHITE}"
        echo "------------------------"
        
        # 检查容器状态
        echo -e "${YELLOW}容器状态:${WHITE}"
        if ! docker ps -f name=$container_name --format "状态: {{.Status}}\t运行时间: {{.RunningFor}}"; then
            log_error "无法获取容器状态"
            sleep 2
            continue
        fi
        
        # 获取MySQL状态
        echo -e "\n${YELLOW}MySQL运行状态:${WHITE}"
        if ! docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root -e "
            SELECT USER as '用户', HOST as '主机', DB as '数据库', COMMAND as '命令', 
                   TIME as '时间(秒)', STATE as '状态'
            FROM information_schema.processlist;
            
            SELECT VARIABLE_VALUE as '最大连接数'
            FROM performance_schema.global_status 
            WHERE VARIABLE_NAME='Max_used_connections';
            
            SELECT VARIABLE_VALUE as '当前连接数'
            FROM performance_schema.global_status 
            WHERE VARIABLE_NAME='Threads_connected';
            
            SELECT VARIABLE_VALUE as '运行时间(秒)'
            FROM performance_schema.global_status 
            WHERE VARIABLE_NAME='Uptime';"; then
            
            log_error "无法获取MySQL状态"
            sleep 2
            continue
        fi
        
        # 显示资源使用情况
        echo -e "\n${YELLOW}资源使用情况:${WHITE}"
        docker stats --no-stream "$container_name"
        
        echo -e "\n按 Ctrl+C 退出监控..."
        sleep 5
    done
}

# 管理MySQL配置
manage_mysql_config() {
    local container_name=$1
    local dbroot_password=$2
    
    while true; do
        clear
        echo -e "${BLUE}MySQL配置管理${WHITE}"
        echo "------------------------"
        echo "1. 查看当前配置"
        echo "2. 修改最大连接数"
        echo "3. 修改缓冲区大小"
        echo "4. 修改超时设置"
        echo "5. 查看变量状态"
        echo "0. 返回上级菜单"
        echo "------------------------"
        
        read -p "请选择操作: " choice
        
        case $choice in
            1)
                clear
                echo -e "${YELLOW}当前MySQL配置:${WHITE}"
                docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root -e "
                    SHOW VARIABLES WHERE Variable_name IN (
                        'max_connections',
                        'connect_timeout',
                        'wait_timeout',
                        'max_allowed_packet',
                        'innodb_buffer_pool_size',
                        'key_buffer_size',
                        'thread_cache_size'
                    );"
                break_end
                ;;
            2)
                read -p "请输入新的最大连接数: " max_conn
                if [[ "$max_conn" =~ ^[0-9]+$ ]]; then
                    if docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root -e "
                        SET GLOBAL max_connections=$max_conn;"; then
                        log_info "最大连接数已更新"
                    else
                        log_error "更新失败"
                    fi
                else
                    log_error "无效的数值"
                fi
                break_end
                ;;
            3)
                read -p "请输入新的InnoDB缓冲池大小(MB): " buffer_size
                if [[ "$buffer_size" =~ ^[0-9]+$ ]]; then
                    buffer_size=$((buffer_size * 1024 * 1024))
                    if docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root -e "
                        SET GLOBAL innodb_buffer_pool_size=$buffer_size;"; then
                        log_info "缓冲池大小已更新"
                    else
                        log_error "更新失败"
                    fi
                else
                    log_error "无效的数值"
                fi
                break_end
                ;;
            4)
                read -p "请输入新的连接超时时间(秒): " timeout
                if [[ "$timeout" =~ ^[0-9]+$ ]]; then
                    if docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root -e "
                        SET GLOBAL wait_timeout=$timeout;
                        SET GLOBAL interactive_timeout=$timeout;"; then
                        log_info "超时设置已更新"
                    else
                        log_error "更新失败"
                    fi
                else
                    log_error "无效的数值"
                fi
                break_end
                ;;
            5)
                clear
                echo -e "${YELLOW}MySQL状态变量:${WHITE}"
                docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root -e "
                    SHOW STATUS WHERE Variable_name IN (
                        'Threads_connected',
                        'Threads_running',
                        'Threads_cached',
                        'Queries',
                        'Slow_queries',
                        'Uptime'
                    );"
                break_end
                ;;
            0)
                break
                ;;
            *)
                log_error "无效的选择"
                ;;
        esac
    done
}

# 管理容器设置
manage_container() {
    local container_name=$1
    local root_password=$2
    
    while true; do
        clear
        echo -e "${BLUE}容器管理${WHITE}"
        echo "------------------------"
        echo "1. 启动容器"
        echo "2. 停止容器"
        echo "3. 重启容器"
        echo "4. 查看容器日志"
        echo "5. 查看容器状态"
        echo "6. 配置管理"
        echo "7. 性能监控"
        echo "0. 返回上级菜单"
        echo "------------------------"
        
        read -p "请选择操作: " choice
        
        case $choice in
            1)
                if ! docker start "$container_name"; then
                    log_error "启动容器失败"
                else
                    log_info "容器已启动"
                fi
                break_end
                ;;
            2)
                if ask_confirmation "确定要停止容器吗？这将中断所有连接"; then
                    if ! docker stop "$container_name"; then
                        log_error "停止容器失败"
                    else
                        log_info "容器已停止"
                    fi
                fi
                break_end
                ;;
            3)
                if ask_confirmation "确定要重启容器吗？这将暂时中断所有连接"; then
                    if ! docker restart "$container_name"; then
                        log_error "重启容器失败"
                    else
                        log_info "容器已重启"
                    fi
                fi
                break_end
                ;;
            4)
                clear
                echo -e "${YELLOW}容器日志:${WHITE}"
                docker logs --tail 100 -f "$container_name"
                break_end
                ;;
            5)
                clear
                echo -e "${YELLOW}容器状态信息:${WHITE}"
                docker stats --no-stream "$container_name"
                docker inspect "$container_name" | grep -v "SHA256" | less
                ;;
            6)
                manage_mysql_config "$container_name" "$root_password"
                ;;
            7)
                monitor_mysql_status "$container_name" "$root_password"
                ;;
            0)
                break
                ;;
            *)
                log_error "无效的选择"
                ;;
        esac
    done
}

###################
# 备份管理功能    #
###################

# 备份数据库
backup_database() {
    local container_name="$1"
    local backup_path="$2"
    local dbroot_password="$3"
    local dbname="${4:-}"
    
    debug "开始备份数据库"
    debug "使用密码: $dbroot_password"
    
    # 验证MySQL连接
    if ! docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" \
        mysql -u root --execute="SELECT 1;" >/dev/null 2>&1; then
        log_error "无法连接到MySQL服务器，请检查密码是否正确"
        return 1
    fi
    
    # 创建备份目录
    mkdir -p "$backup_path"

    local current_time=$(date +"%Y%m%d_%H%M%S")
    local backup_file
    local mysqldump_opts="--single-transaction --quick --lock-tables=false"

    if [ -n "$dbname" ]; then
        # 备份单个数据库
        backup_file="$backup_path/${dbname}_backup_$current_time.sql"
        debug "备份单个数据库: $dbname"
        if ! docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" \
            mysqldump $mysqldump_opts --user=root "$dbname" > "$backup_file" 2>/dev/null; then
            log_error "备份数据库 $dbname 失败"
            return 1
        fi
    else
        # 备份所有数据库
        backup_file="$backup_path/full_backup_$current_time.sql"
        debug "备份所有数据库"
        if ! docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" \
            mysqldump $mysqldump_opts --user=root --all-databases > "$backup_file" 2>/dev/null; then
            log_error "备份所有数据库失败"
            return 1
        fi
    fi

    # 压缩备份文件
    log_info "压缩备份文件..."
    if ! gzip "$backup_file"; then
        log_warning "压缩备份文件失败，但备份文件已保存"
    fi

    local final_file="${backup_file}.gz"
    local backup_size=$(du -h "$final_file" | cut -f1)
    
    log_info "备份完成:"
    echo "位置: $final_file"
    echo "大小: $backup_size"
    
    # 清理旧备份
    cleanup_old_backups "$backup_path"
}

# 清理旧备份
cleanup_old_backups() {
    local backup_dir="$1"
    local max_backups=5  # 保留的最大备份数量
    
    debug "清理旧备份文件"
    
    # 获取备份文件列表（按时间从新到旧排序）
    local backup_files=($(ls -t "$backup_dir"/*.{sql,gz} 2>/dev/null))
    local count=${#backup_files[@]}
    
    if [ $count -gt $max_backups ]; then
        log_info "清理旧备份文件..."
        for ((i=$max_backups; i<$count; i++)); do
            rm -f "${backup_files[$i]}"
            debug "删除文件: ${backup_files[$i]}"
        done
        log_info "已清理 $((count-max_backups)) 个旧备份文件"
    fi
}

# 备份管理菜单
backup_management_menu() {
    local container_name="$1"
    local dbroot_password="$2"
    
    while true; do
        clear
        echo -e "${BLUE}备份管理${WHITE}"
        echo "------------------------"
        echo "---------------------------------------------"
        echo -e "${YELLOW}可用的数据库:${WHITE}"
        echo "---------------------------------------------"
        # 显示所有数据库及其大小
        docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root -N -e "
            SELECT 
                table_schema as '数据库名称',
                ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) as '大小(MB)',
                COUNT(table_name) as '表数量',
                MAX(update_time) as '最后更新'
            FROM information_schema.tables 
            WHERE table_schema NOT IN ('information_schema', 'performance_schema', 'sys')
            GROUP BY table_schema
            ORDER BY table_schema;" | \
        while read -r dbname size tables update; do
            printf "%-20s %-12s %-10s %-20s\n" \
                "${dbname:-'-'}" \
                "${size:-0.00}" \
                "${tables:-0}" \
                "${update:-NULL}"
        done
        
        echo "---------------------------------------------"
        echo "操作选项:"
        echo "1. 备份所有数据库"
        echo "2. 备份单个数据库"
        echo "3. 管理备份文件"
        echo "4. 恢复数据库"
        echo "0. 返回上级菜单"
        echo "---------------------------------------------"
        
        read -p "请选择操作: " choice
        
        case $choice in
            1)
                backup_all_databases "$container_name" "$dbroot_password"
                break_end
                ;;
            2)
                read -p "请输入要备份的数据库名称: " dbname
                if [ -n "$dbname" ]; then
                    backup_database "$container_name" "/home/docker/mysql_backup" "$dbroot_password" "$dbname"
                else
                    log_error "数据库名称不能为空"
                fi
                break_end
                ;;
            3)
                manage_backups
                ;;
            4)
                echo -e "\n${YELLOW}可用的备份文件:${WHITE}"
                echo "---------------------------------------------"
                ls -lh "/home/docker/mysql_backup"
                echo "---------------------------------------------"
                read -p "请输入要恢复的备份文件名: " backup_file
                read -p "请输入要恢复到的数据库名称: " target_db
                if [ -n "$backup_file" ] && [ -n "$target_db" ]; then
                    restore_database "$container_name" "$dbroot_password" "$backup_file" "$target_db"
                else
                    log_error "备份文件名和数据库名称不能为空"
                fi
                break_end
                ;;
            0)
                break
                ;;
            *)
                log_error "无效的选择"
                ;;
        esac
    done
}

# 备份所有数据库函数
backup_all_databases() {
    local container_name="$1"
    local dbroot_password="$2"
    local backup_dir="/home/docker/mysql_backup"
    local current_time=$(date +"%Y%m%d_%H%M%S")
    
    mkdir -p "$backup_dir"
    
    log_info "开始备份所有数据库..."
    if docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" \
        mysqldump -u root --all-databases > "$backup_dir/all_databases_$current_time.sql"; then
        log_info "备份完成: $backup_dir/all_databases_$current_time.sql"
        
        # 自动压缩
        if gzip "$backup_dir/all_databases_$current_time.sql"; then
            log_info "备份文件已压缩"
        else
            log_warning "备份文件压缩失败"
        fi
        
        # 清理旧备份
        cleanup_old_backups "$backup_dir"
    else
        log_error "备份失败"
        return 1
    fi
}

# 还原备份
restore_backup() {
    local container_name="$1"
    local dbroot_password="$2"
    
    clear
    echo -e "${YELLOW}可用的备份文件:${WHITE}"
    ls -1 /home/docker/mysql_backup/
    echo
    
    read -p "请输入要还原的备份文件名: " backup_file
    
    if [ ! -f "/home/docker/mysql_backup/$backup_file" ]; then
        log_error "备份文件不存在"
        return 1
    fi
    
    if ! ask_confirmation "警告：还原操作将覆盖现有数据，是否继续？"; then
        log_info "还原操作已取消"
        return 0
    fi
    
    log_info "开始还原备份..."
    
    case "$backup_file" in
        *.gz)
            if ! zcat "/home/docker/mysql_backup/$backup_file" | \
                docker exec -i "$container_name" mysql -u root -p"$dbroot_password"; then
                log_error "还原失败"
                return 1
            fi
            ;;
        *.sql)
            if ! docker exec -i "$container_name" mysql -u root -p"$dbroot_password" < \
                "/home/docker/mysql_backup/$backup_file"; then
                log_error "还原失败"
                return 1
            fi
            ;;
        *)
            log_error "不支持的文件格式"
            return 1
            ;;
    esac
    
    log_info "备份还原成功"
}

# 数据库管理菜单
database_menu() {
    local container_mysql="$1"
    local credentials=()  # 初始化为空数组
    
    # 获取数据库凭据
    if ! credentials=($(get_db_credentials "$container_mysql")); then
        log_error "无法获取数据库凭据,请检查容器环境变量配置"
        return 1
    fi
    
    while true; do
        clear
        # 检查凭据是否有效
        if [ ${#credentials[@]} -ge 3 ]; then
            mysql_display "$container_mysql" "${credentials[2]}"
        else
            log_error "无效的数据库凭据"
            return 1
        fi

        echo -e "${BLUE}数据库管理${WHITE}"
        echo "------------------------"
        echo "1. 创建新的数据库"
        echo "2. 删除指定数据库"
        echo "3. 导入指定数据库"
        echo "4. 查询指定数据库"
        echo "5. 修改数据库名称"
        echo "6. 管理数据库表"
        echo "0. 返回上级菜单"
        echo "------------------------"

        read -p "请选择操作: " option

        case $option in
            1)
                read -p "请输入新数据库名称: " dbname
                if [ -n "$dbname" ]; then
                    create_database_and_grant "$container_mysql" "$dbname" "${credentials[0]}" "${credentials[1]}" "${credentials[2]}"
                else
                    log_error "数据库名称不能为空"
                fi
                break_end
                ;;
            2)
                read -p "请输入要删除的数据库名称: " dbname
                if [ -n "$dbname" ]; then
                    if ask_confirmation "确定要删除数据库 '$dbname' 吗？此操作不可恢复"; then
                        delete_database "$container_mysql" "$dbname" "${credentials[2]}" "${credentials[0]}"
                    fi
                else
                    log_error "数据库名称不能为空"
                fi
                break_end
                ;;
            3)
                read -p "请输入SQL文件的完整路径: " datafile
                read -p "请输入目标数据库名称: " dbname
                if [ -n "$dbname" ] && [ -n "$datafile" ]; then
                    import_database "$container_mysql" "$dbname" "${credentials[2]}" "$datafile"
                else
                    log_error "数据库名称和文件路径不能为空"
                fi
                break_end
                ;;
            4)
                read -p "请输入要查询的数据库名称: " dbname
                if [ -n "$dbname" ]; then
                    query_database "$container_mysql" "${credentials[2]}" "$dbname"
                else
                    log_error "数据库名称不能为空"
                fi
                break_end
                ;;
            5)
                read -p "请输入要重命名的数据库名称: " old_dbname
                read -p "请输入新的数据库名称: " new_dbname
                if [ -n "$old_dbname" ] && [ -n "$new_dbname" ]; then
                    if ask_confirmation "确定要将数据库 '$old_dbname' 重命名为 '$new_dbname' 吗？"; then
                        rename_database "$container_mysql" "$old_dbname" "$new_dbname" "${credentials[2]}"
                    fi
                else
                    log_error "数据库名称不能为空"
                fi
                break_end
                ;;
            6)
                read -p "请输入要管理的数据库名称: " dbname
                if [ -n "$dbname" ]; then
                    manage_tables "$container_mysql" "$dbname" "${credentials[2]}"
                else
                    log_error "数据库名称不能为空"
                fi
                break_end
                ;;
            0)
                break
                ;;
            *)
                log_error "无效的选项"
                ;;
        esac
    done
}

# 添加性能优化相关函数
check_mysql_performance() {
    local container_name="$1"
    local dbroot_password="$2"
    
    debug "检查MySQL性能指标"
    
    echo -e "${YELLOW}性能检查报告:${WHITE}"
    echo "------------------------"
    
    # 检查慢查询
    local slow_queries=$(docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" \
        mysql -u root -e "SHOW GLOBAL STATUS LIKE 'Slow_queries';" | awk 'NR==2{print $2}')
    echo "慢查询数量: $slow_queries"
    
    # 检查连接数使用情况
    local max_connections=$(docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" \
        mysql -u root -e "SHOW VARIABLES LIKE 'max_connections';" | awk 'NR==2{print $2}')
    local current_connections=$(docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" \
        mysql -u root -e "SHOW STATUS LIKE 'Threads_connected';" | awk 'NR==2{print $2}')
    echo "连接数使用率: $current_connections/$max_connections"
    
    # 检查缓冲池使用情况
    local buffer_pool_size=$(docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" \
        mysql -u root -e "SHOW VARIABLES LIKE 'innodb_buffer_pool_size';" | awk 'NR==2{print $2}')
    echo "InnoDB缓冲池大小: $(( buffer_pool_size / 1024 / 1024 ))MB"
    
    # 检查表缓存使用情况
    local open_tables=$(docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" \
        mysql -u root -e "SHOW STATUS LIKE 'Open_tables';" | awk 'NR==2{print $2}')
    echo "打开的表数量: $open_tables"
}

optimize_mysql_performance() {
    local container_name="$1"
    local dbroot_password="$2"
    
    debug "开始优化MySQL性能"
    
    # 优化InnoDB缓冲池大小
    local total_memory=$(docker exec "$container_name" cat /proc/meminfo | grep MemTotal | awk '{print $2}')
    local recommended_buffer_size=$(( total_memory * 60 / 100 )) # 使用60%的可用内存
    
    docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root -e "
        SET GLOBAL innodb_buffer_pool_size = $recommended_buffer_size;
        SET GLOBAL innodb_flush_method = O_DIRECT;
        SET GLOBAL innodb_flush_log_at_trx_commit = 2;
        SET GLOBAL innodb_file_per_table = 1;"
    
    log_info "InnoDB参数已优化"
    
    # 优化查询缓存
    docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root -e "
        SET GLOBAL query_cache_type = 1;
        SET GLOBAL query_cache_size = 67108864;" # 64MB
    
    log_info "查询缓存已优化"
}

performance_optimization_menu() {
    local container_name="$1"
    local dbroot_password="$2"
    
    while true; do
        clear
        echo -e "${BLUE}性能优化${WHITE}"
        echo "------------------------"
        echo "1. 检查性能状态"
        echo "2. 自动优化性能"
        echo "3. 查看性能建议"
        echo "4. 优化特定数据库"
        echo "0. 返回上级菜单"
        echo "------------------------"
        
        read -p "请选择操作: " choice
        
        case $choice in
            1)
                check_mysql_performance "$container_name" "$dbroot_password"
                break_end
                ;;
            2)
                if ask_confirmation "是否执行自动性能优化？这可能需要重启MySQL服务"; then
                    optimize_mysql_performance "$container_name" "$dbroot_password"
                fi
                break_end
                ;;
            3)
                show_performance_recommendations "$container_name" "$dbroot_password"
                break_end
                ;;
            4)
                read -p "请输入要优化的数据库名称: " dbname
                if [ -n "$dbname" ]; then
                    optimize_database "$container_name" "$dbname" "$dbroot_password"
                fi
                break_end
                ;;
            0)
                break
                ;;
            *)
                log_error "无效的选择"
                ;;
        esac
    done
}

# 增强备份管理功能
manage_backups() {
    local backup_dir="/home/docker/mysql_backup"
    
    while true; do
        clear
        echo -e "${BLUE}备份文件管理${WHITE}"
        echo "------------------------"
        echo "1. 查看所有备份"
        echo "2. 删除指定备份"
        echo "3. 清理过期备份"
        echo "4. 压缩备份文件"
        echo "0. 返回上级菜单"
        echo "------------------------"
        
        read -p "请选择操作: " choice
        
        case $choice in
            1)
                clear
                echo -e "${YELLOW}备份文件列表:${WHITE}"
                echo "------------------------"
                ls -lh "$backup_dir"
                break_end
                ;;
            2)
                read -p "请输入要删除的备份文件名: " filename
                if [ -f "$backup_dir/$filename" ]; then
                    if ask_confirmation "确定要删除备份文件 '$filename' 吗？"; then
                        rm -f "$backup_dir/$filename"
                        log_info "备份文件已删除"
                    fi
                else
                    log_error "文件不存在"
                fi
                break_end
                ;;
            3)
                if ask_confirmation "是否清理超过 $BACKUP_RETENTION_DAYS 天的备份文件？"; then
                    find "$backup_dir" -type f -mtime +$BACKUP_RETENTION_DAYS -delete
                    log_info "过期备份已清理"
                fi
                break_end
                ;;
            4)
                for file in "$backup_dir"/*.sql; do
                    if [ -f "$file" ]; then
                        log_info "压缩文件: $file"
                        gzip -f "$file"
                    fi
                done
                log_info "所有SQL文件已压缩"
                break_end
                ;;
            0)
                break
                ;;
            *)
                log_error "无效的选择"
                ;;
        esac
    done
}

# 主菜单
main_menu() {
    local search_term="$1"
    local container_mysql=""  # 初始化为空字符串
    local credentials=()  # 初始化为空数组
    
    while true; do
        clear
        echo -e "${BLUE}▶ MySQL管理器${WHITE}"
        echo "------------------------"
        echo "1. 安装/更新MySQL环境"
        echo "2. 数据库管理"
        echo "3. 备份管理"
        echo "4. 容器管理"
        echo "5. 状态监控"
        echo "6. 性能优化"
        echo "0. 退出"
        echo "------------------------"
        
        # 在每次循环开始时检查MySQL容器状态
        if [ -z "$container_mysql" ]; then
            container_mysql=$(get_db_container_name "$search_term" 2>/dev/null || echo "")
        fi
        
        read -p "请选择功能: " choice

        case $choice in
            1)  
                update_mysql_env
                # 重新检查容器状态
                container_mysql=$(get_db_container_name "$search_term" 2>/dev/null || echo "")
                ;;            
            2|3|4|5|6)
                if [ -z "$container_mysql" ]; then
                    log_warning "未检测到运行中的MySQL容器"
                    if ask_confirmation "是否现在安装MySQL环境？"; then
                        update_mysql_env
                        # 重新检查容器状态
                        container_mysql=$(get_db_container_name "$search_term" 2>/dev/null || echo "")
                        if [ -z "$container_mysql" ]; then
                            log_error "MySQL环境安装失败或未正确启动"
                            break_end
                            continue
                        fi
                    else
                        log_info "请先安装MySQL环境后再执行该操作"
                        break_end
                        continue
                    fi
                fi
                
                # 确保在使用credentials之前初始化它
                if [ "$choice" -eq 2 ]; then
                    # 获取数据库凭据
                    if ! credentials=($(get_db_credentials "$container_mysql")); then
                        log_error "无法获取数据库凭据,请检查容器环境变量配置"
                        break_end
                        continue
                    fi
                    database_menu "$container_mysql" "${credentials[@]}"
                elif [ "$choice" -eq 3 ]; then
                    # 确保在使用credentials之前获取它
                    if [ ${#credentials[@]} -eq 0 ]; then
                        if ! credentials=($(get_db_credentials "$container_mysql")); then
                            log_error "无法获取数据库凭据,请检查容器环境变量配置"
                            break_end
                            continue
                        fi
                    fi
                    backup_management_menu "$container_mysql" "${credentials[2]}"
                elif [ "$choice" -eq 4 ]; then
                    # 确保在使用credentials之前获取它
                    if [ ${#credentials[@]} -eq 0 ]; then
                        if ! credentials=($(get_db_credentials "$container_mysql")); then
                            log_error "无法获取数据库凭据,请检查容器环境变量配置"
                            break_end
                            continue
                        fi
                    fi
                    manage_container "$container_mysql" "${credentials[2]}"
                elif [ "$choice" -eq 5 ]; then  
                    # 确保在使用credentials之前获取它
                    if [ ${#credentials[@]} -eq 0 ]; then
                        if ! credentials=($(get_db_credentials "$container_mysql")); then
                            log_error "无法获取数据库凭据,请检查容器环境变量配置"
                            break_end
                            continue
                        fi
                    fi
                    monitor_mysql_status "$container_mysql" "${credentials[2]}"
                elif [ "$choice" -eq 6 ]; then
                    # 确保在使用credentials之前获取它
                    if [ ${#credentials[@]} -eq 0 ]; then
                        if ! credentials=($(get_db_credentials "$container_mysql")); then
                            log_error "无法获取数据库凭据,请检查容器环境变量配置"
                            break_end
                            continue
                        fi
                    fi
                    performance_optimization_menu "$container_mysql" "${credentials[2]}" 
                fi
                ;;
            0)
                echo "感谢使用MySQL管理器，再见！"
                exit 0
                ;;
            *)
                log_error "无效的选择"
                ;;
        esac
    done
}

# 主程序入口
main() {
    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi

    # 检查Docker环境
    check_docker_installed || {
        log_error "请先安装并启动Docker"
        exit 1
    }

    # 解析命令行参数
    local command="$1"
    case "$command" in
        manage)
            if [ $# -lt 2 ]; then
                log_error "请指定MySQL容器名称"
                show_usage
                exit 1
            fi
            main_menu "$2"
            ;;
        create|delete|backup)
            if [ $# -lt 3 ]; then
                log_error "参数不足"
                show_usage
                exit 1
            fi
            handle_command "$@"
            ;;
        *)
            log_error "未知命令: $command"
            show_usage
            exit 1
            ;;
    esac
}

# 显示使用说明
show_usage() {
    cat << EOF
使用方法: $(basename "$0") <命令> [选项...]

命令:
    manage <容器>        - 启动MySQL管理界面
    create <容器> <库名> - 创建新数据库
    delete <容器> <库名> - 删除数据库
    backup <容器> <库名> - 备份数据库

示例:
    $(basename "$0") manage mysql
    $(basename "$0") create mysql mydb
    $(basename "$0") delete mysql mydb
    $(basename "$0") backup mysql mydb
EOF
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
