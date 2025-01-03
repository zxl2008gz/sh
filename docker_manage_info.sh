#!/bin/bash

# 在文件开头添加日志功能
LOG_FILE="/var/log/docker_manage.log"
LOG_MAX_SIZE=10485760  # 10MB

# 日志函数
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # 日志轮转
    if [ -f "$LOG_FILE" ] && [ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE") -gt $LOG_MAX_SIZE ]; then
        mv "$LOG_FILE" "${LOG_FILE}.old"
    fi
}

# 定义颜色变量
huang='\033[33m'
bai='\033[0m'
lv='\033[0;32m'
lan='\033[0;34m'
hong='\033[31m'
lianglan='\033[96m'
hui='\e[37m'

# 增强的错误处理函数
handle_error() {
    local error_message="$1"
    local error_code="${2:-1}"
    echo -e "${hong}错误: ${error_message}${bai}" >&2
    log "ERROR" "$error_message"
    return $error_code
}

# 成功消息函数
show_success() {
    local message="$1"
    echo -e "${lv}${message}${bai}"
}

# 等待用户输入函数
break_end() {
    show_success "操作完成"
    echo "按任意键继续..."
    read -n 1 -s -r -p ""
    echo
    clear
}

# 检查Docker是否安装及其状态
check_docker_status() {
    if ! command -v docker &>/dev/null; then
        handle_error "Docker 未安装"
        return 1
    fi

    if ! docker info &>/dev/null; then
        handle_error "Docker 守护进程未运行"
        return 2
    fi

    return 0
}

# 验证容器名称是否有效
validate_container_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]+$ ]]; then
        handle_error "无效的容器名称。只允许字母、数字、下划线、点和横线，且必须以字母或数字开头"
        return 1
    fi
    return 0
}

# 增强的确认函数
ask_confirmation() {
    local prompt="$1"
    local default="${2:-N}"  # 默认为N
    local choice

    while true; do
        read -p "$prompt (y/n) [${default}]: " choice
        choice=${choice:-$default}
        case "${choice,,}" in  # 转换为小写
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) echo "请输入 y 或 n" ;;
        esac
    done
}

# 检查并限制Docker日志大小
setup_docker_logging() {
    local max_size="${1:-20m}"
    local max_file="${2:-3}"
    
    local daemon_config="/etc/docker/daemon.json"
    local temp_config="/tmp/daemon.json"

    # 确保目录存在
    mkdir -p /etc/docker

    # 如果配置文件存在，保留现有配置
    if [ -f "$daemon_config" ]; then
        jq --arg size "$max_size" --arg files "$max_file" '.["log-driver"]="json-file" | .["log-opts"]["max-size"]=$size | .["log-opts"]["max-file"]=$files' "$daemon_config" > "$temp_config"
    else
        # 创建新配置
        cat > "$temp_config" <<EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "$max_size",
        "max-file": "$max_file"
    }
}
EOF
    fi

    # 验证JSON格式
    if jq empty "$temp_config" 2>/dev/null; then
        mv "$temp_config" "$daemon_config"
        show_success "Docker日志配置已更新"
        return 0
    else
        handle_error "JSON验证失败，配置未更新"
        rm -f "$temp_config"
        return 1
    fi
}

# 函数：启用Docker的IPv6支持
docker_ipv6_on() {
    # 创建配置目录（如果不存在）
    mkdir -p /etc/docker

    # 写入IPv6配置到daemon.json
    cat > /etc/docker/daemon.json << EOF
{
    "ipv6": true,
    "fixed-cidr-v6": "2001:db8:1::/64",
    "experimental": true,
    "ip6tables": true
}
EOF

    # 重启Docker服务以应用更改
    if [ -f "/etc/alpine-release" ]; then
        service docker restart || rc-service docker restart
    else
        systemctl restart docker
    fi

    show_success "Docker已开启IPv6访问"
}

# 函数：禁用Docker的IPv6支持
docker_ipv6_off() {
    # 备份现有配置
    if [ -f "/etc/docker/daemon.json" ]; then
        cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
        # 删除IPv6相关配置
        jq 'del(.ipv6) | del(.["fixed-cidr-v6"]) | del(.experimental) | del(.ip6tables)' /etc/docker/daemon.json.bak > /etc/docker/daemon.json
    fi

    # 重启Docker服务以应用更改
    if [ -f "/etc/alpine-release" ]; then
        service docker restart || rc-service docker restart
    else
        systemctl restart docker
    fi

    show_success "Docker已关闭IPv6访问"
}

# 添加命令执行超时控制函数
execute_with_timeout() {
    local cmd="$1"
    local timeout="${2:-300}"  # 默认5分钟超时
    local message="${3:-执行命令}"
    
    # 显示进度条
    (
        i=0
        while [ $i -lt $timeout ] && kill -0 $$ 2>/dev/null; do
            printf "\r${message} [%-50s] %d%%" "$(printf '#%.0s' $(seq 1 $((i*50/timeout))))" $((i*100/timeout))
            sleep 1
            i=$((i+1))
        done
    ) &
    progress_pid=$!

    # 执行命令
    eval "$cmd" &
    cmd_pid=$!

    # 等待命令执行完成或超时
    local wait_result=0
    if ! wait -n $cmd_pid 2>/dev/null; then
        wait_result=$?
        kill $progress_pid 2>/dev/null
        handle_error "${message}失败 (超时)" $wait_result
        return $wait_result
    fi

    kill $progress_pid 2>/dev/null
    printf "\r${message} [%-50s] %d%%\n" "$(printf '#%.0s' $(seq 1 50))" 100
    return 0
}

# 添加配置文件支持
CONFIG_FILE="/etc/docker_manage.conf"

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        # 创建默认配置
        cat > "$CONFIG_FILE" << EOF
# Docker管理脚本配置文件
DOCKER_LOG_MAX_SIZE=20m
DOCKER_LOG_MAX_FILE=3
DOCKER_REGISTRY_MIRROR="https://mirror.ccs.tencentyun.com"
DOCKER_DATA_ROOT="/var/lib/docker"
DOCKER_IPV6_ENABLED=false
EOF
    fi
}

# 修改update_docker函数，添加进度显示
update_docker() {
    log "INFO" "开始更新Docker"
    
    # 检查是否为root用户
    if [ "$(id -u)" != "0" ]; then
        handle_error "此操作需要root权限"
        return 1
    fi

    # 备份现有Docker配置
    if [ -d "/etc/docker" ]; then
        backup_dir="/root/docker_backup_$(date +%Y%m%d_%H%M%S)"
        execute_with_timeout "mkdir -p '$backup_dir' && cp -r /etc/docker '$backup_dir'" 60 "备份Docker配置"
        show_success "已备份Docker配置到 $backup_dir"
        log "INFO" "Docker配置已备份到 $backup_dir"
    fi

    # 根据不同的Linux发行版安装Docker
    if [ -f "/etc/alpine-release" ]; then
        execute_with_timeout "apk update && apk add docker docker-compose" 300 "安装Docker"
    else
        execute_with_timeout "curl -fsSL https://get.docker.com | sh" 600 "安装Docker"
    fi

    # 设置镜像加速
    if [ -n "$DOCKER_REGISTRY_MIRROR" ]; then
        mkdir -p /etc/docker
        cat > /etc/docker/daemon.json << EOF
{
    "registry-mirrors": ["$DOCKER_REGISTRY_MIRROR"],
    "data-root": "$DOCKER_DATA_ROOT"
}
EOF
    fi

    log "INFO" "Docker更新完成"
    show_success "Docker 安装/更新成功"
}

# 卸载Docker环境
uninstall_docker() {
    clear
    echo "此操作将完全卸载Docker环境，包括所有容器、镜像和网络配置。"
    
    if ! ask_confirmation "确定要卸载Docker环境吗？" "n"; then
        echo "卸载操作已取消"
        return 0
    fi

    # 停止所有容器
    echo "停止所有正在运行的容器..."
    docker stop $(docker ps -q) 2>/dev/null || true

    # 删除所有容器
    echo "删除所有容器..."
    docker rm -f $(docker ps -a -q) 2>/dev/null || true

    # 删除所有镜像
    echo "删除所有镜像..."
    docker rmi -f $(docker images -q) 2>/dev/null || true

    # 清理所有卷和网络
    echo "清理所有网络和数据卷..."
    docker network prune -f 2>/dev/null || true
    docker volume prune -f 2>/dev/null || true

    # 根据不同的发行版执行卸载
    if command -v apt-get &>/dev/null; then
        apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        apt-get autoremove -y
    elif command -v yum &>/dev/null; then
        yum remove -y docker docker-client docker-client-latest docker-common \
            docker-latest docker-latest-logrotate docker-logrotate docker-engine
    elif command -v apk &>/dev/null; then
        apk del docker docker-compose
    else
        handle_error "未识别的包管理器"
        return 1
    fi

    # 删除Docker相关目录和文件
    echo "清理Docker相关文件和目录..."
    rm -rf /var/lib/docker
    rm -rf /var/lib/containerd
    rm -rf /etc/docker
    rm -rf ~/.docker

    show_success "Docker已完全卸载"
    return 0
}

# 增强的Docker状态显示函数
state_docker() {
    local output=""
    
    # 系统信息
    output+="系统信息:\n"
    output+="$(uname -a)\n"
    output+="---------------------------------------------\n"

    # Docker版本信息
    output+="Docker 版本:\n"
    output+="$(docker --version)\n"
    if command -v docker-compose &>/dev/null; then
        output+="$(docker-compose --version)\n"
    fi
    output+="---------------------------------------------\n"

    # Docker系统信息
    output+="Docker 系统信息:\n"
    output+="$(docker info | grep -E 'Storage Driver|Logging Driver|Cgroup Driver|Docker Root Dir|Debug Mode')\n"
    output+="---------------------------------------------\n"

    # 资源使用情况
    output+="资源使用情况:\n"
    output+="$(docker system df)\n"
    output+="---------------------------------------------\n"

    # Docker镜像列表
    output+="Docker 镜像列表:\n"
    output+="$(docker image ls --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}')\n"
    output+="---------------------------------------------\n"

    # Docker容器列表
    output+="Docker 容器列表:\n"
    output+="$(docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}')\n"
    output+="---------------------------------------------\n"

    # Docker卷列表
    output+="Docker 卷列表:\n"
    output+="$(docker volume ls)\n"
    output+="---------------------------------------------\n"

    # Docker网络列表
    output+="Docker 网络列表:\n"
    output+="$(docker network ls)\n"
    output+="---------------------------------------------\n"

    # 使用less显示输出，支持滚动
    echo -e "$output" | less -R
}

# 增强的容器管理函数
docker_container_manage() {
    while true; do
        clear
        echo -e "${lianglan}Docker容器管理${bai}"
        echo "当前运行的容器:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo -e "\n已停止的容器:"
        docker ps -f "status=exited" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        
        echo -e "\n${huang}容器操作菜单${bai}"
        echo "------------------------"
        echo "1. 创建新容器"
        echo "2. 启动容器"
        echo "3. 停止容器"
        echo "4. 重启容器"
        echo "5. 删除容器"
        echo "6. 查看容器日志"
        echo "7. 进入容器终端"
        echo "8. 查看容器详细信息"
        echo "9. 导出容器"
        echo "10. 批量操作"
        echo "0. 返回上级菜单"
        echo "------------------------"

        read -p "请选择操作 [0-10]: " choice

        case $choice in
            1)
                read -p "请输入完整的docker run命令: " cmd
                eval "$cmd" || handle_error "创建容器失败"
                ;;
            2|3|4|5|6|7|8|9)
                read -p "请输入容器名称或ID: " container
                if ! docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
                    handle_error "容器不存在"
                    continue
                fi
                
                case $choice in
                    2) docker start "$container" ;;
                    3) docker stop "$container" ;;
                    4) docker restart "$container" ;;
                    5)
                        if ask_confirmation "确定要删除容器 $container 吗?"; then
                            docker rm -f "$container"
                        fi
                        ;;
                    6)
                        echo "按 Ctrl+C 退出日志查看"
                        docker logs -f "$container"
                        ;;
                    7)
                        echo "输入 'exit' 退出容器"
                        docker exec -it "$container" /bin/bash || docker exec -it "$container" /bin/sh
                        ;;
                    8)
                        docker inspect "$container" | less
                        ;;
                    9)
                        output_file="${container}_$(date +%Y%m%d_%H%M%S).tar"
                        docker export "$container" > "$output_file"
                        show_success "容器已导出到 $output_file"
                        ;;
                esac
                ;;
            10)
                echo "批量操作菜单:"
                echo "1. 启动所有容器"
                echo "2. 停止所有容器"
                echo "3. 删除所有停止的容器"
                echo "4. 删除所有容器"
                read -p "请选择批量操作 [1-4]: " batch_choice
                
                case $batch_choice in
                    1) 
                        container_count=$(docker ps -aq | wc -l)
                        if [ "$container_count" -gt 0 ] && ask_confirmation "确定要启动所有 $container_count 个容器吗?"; then
                            execute_with_timeout "docker start \$(docker ps -aq)" 300 "启动所有容器"
                        fi
                        ;;
                    2) docker stop $(docker ps -q) ;;
                    3) docker container prune -f ;;
                    4)
                        if ask_confirmation "确定要删除所有容器吗？"; then
                            docker rm -f $(docker ps -aq)
                        fi
                        ;;
                    *) handle_error "无效的选择" ;;
                esac
                ;;
            0) break ;;
            *) handle_error "无效的选择" ;;
        esac
        break_end
    done
}

# 增强的镜像管理函数
image_management() {
    while true; do
        clear
        echo -e "${lianglan}Docker镜像管理${bai}"
        docker image ls
        
        echo -e "\n${huang}镜像操作菜单${bai}"
        echo "------------------------"
        echo "1. 拉取镜像"
        echo "2. 删除镜像"
        echo "3. 导出镜像"
        echo "4. 导入镜像"
        echo "5. 构建镜像"
        echo "6. 清理未使用的镜像"
        echo "7. 查看镜像历史"
        echo "8. 为镜像添加标签"
        echo "0. 返回上级菜单"
        echo "------------------------"

        read -p "请选择操作 [0-8]: " choice

        case $choice in
            1)
                read -p "请输入镜像名称 [格式: 名称:标签]: " image
                docker pull "$image" || handle_error "拉取镜像失败"
                ;;
            2)
                read -p "请输入要删除的镜像ID或名称: " image
                if ask_confirmation "确定要删除镜像 $image 吗?"; then
                    docker rmi -f "$image" || handle_error "删除镜像失败"
                fi
                ;;
            3)
                read -p "请输入要导出的镜像名称: " image
                output_file="${image//\//_}_$(date +%Y%m%d_%H%M%S).tar"
                docker save "$image" > "$output_file" && \
                show_success "镜像已导出到 $output_file"
                ;;
            4)
                read -p "请输入要导入的镜像文件路径: " image_file
                if [ -f "$image_file" ]; then
                    docker load < "$image_file"
                else
                    handle_error "文件不存在"
                fi
                ;;
            5)
                read -p "请输入Dockerfile所在目录: " dockerfile_path
                read -p "请输入镜像名称和标签: " image_name
                if [ -d "$dockerfile_path" ]; then
                    docker build -t "$image_name" "$dockerfile_path"
                else
                    handle_error "目录不存在"
                fi
                ;;
            6)
                if ask_confirmation "确定要清理未使用的镜像吗?"; then
                    docker image prune -af
                fi
                ;;
            7)
                read -p "请输入镜像名称: " image
                docker history "$image" | less
                ;;
            8)
                read -p "请输入源镜像名称: " source_image                
				read -p "请输入新标签: " new_tag
                docker tag "$source_image" "$new_tag" || handle_error "添加标签失败"
                ;;
            0) break ;;
            *) handle_error "无效的选择" ;;
        esac
        break_end
    done
}

# 增强的网络管理函数
network_management() {
    while true; do
        clear
        echo -e "${lianglan}Docker网络管理${bai}"
        docker network ls
        
        # 显示网络详细信息
        echo -e "\n当前网络使用情况:"
        printf "%-25s %-25s %-15s\n" "网络名称" "容器名称" "IP地址"
        echo "------------------------------------------------------------"
        for network in $(docker network ls --format "{{.Name}}"); do
            # 获取该网络下的所有容器信息
            containers=$(docker network inspect "$network" --format '{{range .Containers}}{{.Name}} {{.IPv4Address}} {{end}}')
            if [ -n "$containers" ]; then
                echo -e "\n${lianglan}$network${bai}"
                while read -r name ip; do
                    if [ -n "$name" ] && [ -n "$ip" ]; then
                        printf "%-20s %-20s %-15s\n" "" "$name" "$ip"
                    fi
                done <<< "$(echo "$containers" | tr ' ' '\n' | sed 'N;s/\n/ /')"
            fi
        done
        
        echo -e "\n${huang}网络操作菜单${bai}"
        echo "------------------------"
        echo "1. 创建新网络"
        echo "2. 删除网络"
        echo "3. 连接容器到网络"
        echo "4. 断开容器与网络的连接"
        echo "5. 查看网络详细信息"
        echo "6. 清理未使用的网络"
        echo "7. 创建带子网的网络"
        echo "0. 返回上级菜单"
        echo "------------------------"

        read -p "请选择操作 [0-7]: " choice

        case $choice in
            1)
                read -p "请输入网络名称: " network_name
                read -p "请选择驱动(bridge/overlay/host/macvlan): " driver
                driver=${driver:-bridge}
                docker network create --driver "$driver" "$network_name" || handle_error "创建网络失败"
                ;;
            2)
                read -p "请输入要删除的网络名称: " network_name
                if ask_confirmation "确定要删除网络 $network_name 吗?"; then
                    docker network rm "$network_name" || handle_error "删除网络失败"
                fi
                ;;
            3)
                read -p "请输入容器名称: " container
                read -p "请输入网络名称: " network
                docker network connect "$network" "$container" || handle_error "连接网络失败"
                ;;
            4)
                read -p "请输入容器名称: " container
                read -p "请输入网络名称: " network
                docker network disconnect "$network" "$container" || handle_error "断开网络失败"
                ;;
            5)
                read -p "请输入网络名称: " network
                docker network inspect "$network" | less
                ;;
            6)
                if ask_confirmation "确定要清理未使用的网络吗?"; then
                    docker network prune -f
                fi
                ;;
            7)
                read -p "请输入网络名称: " network_name
                read -p "请输入子网CIDR(例如: 172.20.0.0/16): " subnet
                read -p "请输入网关IP(例如: 172.20.0.1): " gateway
                docker network create --subnet "$subnet" --gateway "$gateway" "$network_name" || \
                    handle_error "创建网络失败"
                ;;
            0) break ;;
            *) handle_error "无效的选择" ;;
        esac
        break_end
    done
}

# 增强的数据卷管理函数
volume_management() {
    while true; do
        clear
        echo -e "${lianglan}Docker数据卷管理${bai}"
        docker volume ls
        
        echo -e "\n${huang}数据卷操作菜单${bai}"
        echo "------------------------"
        echo "1. 创建数据卷"
        echo "2. 删除数据卷"
        echo "3. 查看数据卷详情"
        echo "4. 清理未使用的数据卷"
        echo "5. 备份数据卷"
        echo "6. 恢复数据卷"
        echo "0. 返回上级菜单"
        echo "------------------------"

        read -p "请选择操作 [0-6]: " choice

        case $choice in
            1)
                read -p "请输入数据卷名称: " volume_name
                docker volume create "$volume_name" || handle_error "创建数据卷失败"
                ;;
            2)
                read -p "请输入要删除的数据卷名称: " volume_name
                if ask_confirmation "确定要删除数据卷 $volume_name 吗?"; then
                    docker volume rm "$volume_name" || handle_error "删除数据卷失败"
                fi
                ;;
            3)
                read -p "请输入数据卷名称: " volume_name
                docker volume inspect "$volume_name" | less
                ;;
            4)
                if ask_confirmation "确定要清理未使用的数据卷吗?"; then
                    docker volume prune -f
                fi
                ;;
            5)
                read -p "请输入要备份的数据卷名称: " volume_name
                backup_file="${volume_name}_backup_$(date +%Y%m%d_%H%M%S).tar"
                docker run --rm -v "$volume_name":/source:ro -v "$(pwd)":/backup alpine tar cf "/backup/$backup_file" -C /source .
                show_success "数据卷已备份到 $backup_file"
                ;;
            6)
                read -p "请输入要恢复的备份文件路径: " backup_file
                read -p "请输入目标数据卷名称: " volume_name
                if [ -f "$backup_file" ]; then
                    docker volume create "$volume_name" 2>/dev/null
                    docker run --rm -v "$volume_name":/target -v "$(pwd)":/backup alpine tar xf "/backup/$(basename "$backup_file")" -C /target
                    show_success "数据卷已恢复"
                else
                    handle_error "备份文件不存在"
                fi
                ;;
            0) break ;;
            *) handle_error "无效的选择" ;;
        esac
        break_end
    done
}

# 系统清理函数
clean_docker_system() {
    clear
    echo "Docker系统清理"
    echo "------------------------"
    echo "1. 显示当前磁盘使用情况"
    echo "2. 清理未使用的容器"
    echo "3. 清理未使用的镜像"
    echo "4. 清理未使用的数据卷"
    echo "5. 清理未使用的网络"
    echo "6. 清理构建缓存"
    echo "7. 全面清理（慎用）"
    echo "0. 返回上级菜单"
    echo "------------------------"

    read -p "请选择要执行的清理操作 [0-7]: " choice

    case $choice in
        1)
            echo "系统使用情况:"
            docker system df -v | less
            ;;
        2)
            if ask_confirmation "确定要清理未使用的容器吗?"; then
                docker container prune -f
            fi
            ;;
        3)
            if ask_confirmation "确定要清理未使用的镜像吗?"; then
                docker image prune -af
            fi
            ;;
        4)
            if ask_confirmation "确定要清理未使用的数据卷吗?"; then
                docker volume prune -f
            fi
            ;;
        5)
            if ask_confirmation "确定要清理未使用的网络吗?"; then
                docker network prune -f
            fi
            ;;
        6)
            if ask_confirmation "确定要清理构建缓存吗?"; then
                docker builder prune -af
            fi
            ;;
        7)
            if ask_confirmation "这将清理所有未使用的Docker资源，确定要继续吗?" "n"; then
                docker system prune -af --volumes
            fi
            ;;
        0) return ;;
        *) handle_error "无效的选择" ;;
    esac
    break_end
}

# 添加性能监控增强功能
monitor_docker_performance() {
    local interval="${1:-5}"  # 默认5秒刷新一次
    
    while true; do
        clear
        echo -e "${lianglan}Docker性能监控 (每${interval}秒刷新)${bai}"
        echo "按 Ctrl+C 退出监控"
        echo "----------------------------------------"
        
        # 显示系统资源使用情况
        echo "系统资源使用情况:"
        free -h | head -n 2
        echo "CPU使用率: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')%"
        
        # 显示Docker容器资源使用情况
        echo -e "\nDocker容器资源使用情况:"
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
        
        sleep $interval
    done
}

# 添加重试机制函数
retry_command() {
    local cmd="$1"
    local max_attempts="${2:-3}"
    local delay="${3:-5}"
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if eval "$cmd"; then
            return 0
        else
            log "WARN" "命令执行失败，尝试 $attempt/$max_attempts"
            echo -e "${huang}命令执行失败，${delay}秒后重试 ($attempt/$max_attempts)${bai}"
            sleep $delay
            attempt=$((attempt + 1))
        fi
    done
    
    handle_error "命令执行失败，已达到最大重试次数"
    return 1
}

# 添加健康检查函数
check_docker_health() {
    local issues=()
    
    # 检查Docker守护进程状态
    if ! systemctl is-active --quiet docker 2>/dev/null; then
        issues+=("Docker守护进程未运行")
    fi
    
    # 检查磁盘空间
    local docker_root=$(docker info --format '{{.DockerRootDir}}')
    local available_space=$(df -h "$docker_root" | awk 'NR==2 {print $4}')
    if [[ $(df -k "$docker_root" | awk 'NR==2 {print $4}') -lt 1048576 ]]; then  # 1GB
        issues+=("Docker根目录空间不足 (可用: $available_space)")
    fi
    
    # 检查系统资源
    local memory_usage=$(free | awk '/Mem:/ {print int($3/$2 * 100)}')
    if [ "$memory_usage" -gt 90 ]; then
        issues+=("系统内存使用率过高: ${memory_usage}%")
    fi
    
    # 检查Docker配置
    if ! docker info --format '{{.ServerVersion}}' >/dev/null 2>&1; then
        issues+=("Docker配置可能存在问题")
    fi
    
    # 返回检查结果
    if [ ${#issues[@]} -eq 0 ]; then
        show_success "Docker运行状况良好"
        return 0
    else
        echo -e "${hong}发现以下问题:${bai}"
        printf '%s\n' "${issues[@]}"
        return 1
    fi
}

# 增强的备份功能
backup_docker() {
    local backup_dir="/root/docker_backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # 备份Docker配置
    if [ -d "/etc/docker" ]; then
        cp -r /etc/docker "$backup_dir/docker_config"
    fi
    
    # 备份容器定义
    docker inspect $(docker ps -aq) > "$backup_dir/containers.json" 2>/dev/null
    
    # 备份重要数据卷
    echo "正在备份数据卷..."
    for volume in $(docker volume ls -q); do
        echo "备份数据卷: $volume"
        docker run --rm -v "$volume":/source:ro -v "$backup_dir/volumes":/backup alpine \
            tar czf "/backup/${volume}.tar.gz" -C /source .
    done
    
    # 创建备份清单
    {
        echo "备份时间: $(date)"
        echo "Docker版本: $(docker --version)"
        echo "容器列表:"
        docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
        echo "数据卷列表:"
        docker volume ls
    } > "$backup_dir/backup_manifest.txt"
    
    # 压缩备份
    tar czf "${backup_dir}.tar.gz" -C "$(dirname "$backup_dir")" "$(basename "$backup_dir")"
    rm -rf "$backup_dir"
    
    show_success "备份完成: ${backup_dir}.tar.gz"
    log "INFO" "Docker备份完成: ${backup_dir}.tar.gz"
}

# 增强的性能监控函数
monitor_docker_performance() {
    local interval="${1:-5}"
    local stats_file="/tmp/docker_stats.log"
    
    trap 'rm -f $stats_file; exit 0' INT TERM
    
    while true; do
        clear
        echo -e "${lianglan}Docker性能监控 (每${interval}秒刷新)${bai}"
        echo "按 Ctrl+C 退出监控"
        echo "----------------------------------------"
        
        # 系统资源使用情况
        echo "系统资源使用情况:"
        echo "CPU使用率: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')%"
        free -h | head -n 2
        echo "磁盘使用情况:"
        df -h $(docker info --format '{{.DockerRootDir}}') | tail -n 1
        
        # Docker资源使用情况
        echo -e "\nDocker资源使用情况:"
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" | tee "$stats_file"
        
        # 显示高资源占用的容器
        echo -e "\n资源使用率较高的容器:"
        grep -v "NAME" "$stats_file" | sort -k2 -r | head -n 3
        
        # 显示网络IO较高的容器
        echo -e "\n网络IO较高的容器:"
        grep -v "NAME" "$stats_file" | sort -k4 -r | head -n 3
        
        sleep "$interval"
    done
}

# 添加安全检查函数
check_docker_security() {
    local issues=()
    
    # 检查Docker配置安全性
    if docker info 2>/dev/null | grep -q "Insecure Registries"; then
        issues+=("发现不安全的镜像仓库配置")
    fi
    
    # 检查容器安全配置
    for container in $(docker ps -q); do
        # 检查特权容器
        if docker inspect "$container" --format '{{.HostConfig.Privileged}}' | grep -q "true"; then
            issues+=("容器 $(docker inspect "$container" --format '{{.Name}}') 运行在特权模式")
        fi
        
        # 检查端口暴露
        if docker port "$container" &>/dev/null; then
            issues+=("容器 $(docker inspect "$container" --format '{{.Name}}') 暴露了端口")
        fi
    done
    
    # 检查Docker守护进程配置
    if [ -f "/etc/docker/daemon.json" ]; then
        if ! jq empty "/etc/docker/daemon.json" 2>/dev/null; then
            issues+=("Docker守护进程配置文件格式无效")
        fi
    fi
    
    # 返回检查结果
    if [ ${#issues[@]} -eq 0 ]; then
        show_success "未发现安全问题"
        return 0
    else
        echo -e "${hong}发现以下安全问题:${bai}"
        printf '%s\n' "${issues[@]}"
        return 1
    fi
}

# Docker主菜单函数
docker_manage() {
    while true; do
        clear
        echo -e "${lianglan}Docker管理系统${bai}"
        echo "------------------------"
        echo "1. 安装/更新Docker"
        echo "2. 查看Docker状态"
        echo "3. 容器管理"
        echo "4. 镜像管理"
        echo "5. 网络管理"
        echo "6. 数据卷管理"
        echo "7. 系统清理"
        echo "8. 更换Docker源"
        echo "9. 修改日志配置"
        echo "10. IPv6管理"
        echo "11. 性能监控"
        echo "12. 健康检查"
        echo "13. 备份Docker环境"
        echo "14. 安全检查"
        echo "50. 卸载Docker"
        echo "0. 退出"
        echo "------------------------"

        read -p "请选择操作 [0-50]: " choice

        case $choice in
            1) update_docker ;;
            2) state_docker ;;
            3) docker_container_manage ;;
            4) image_management ;;
            5) network_management ;;
            6) volume_management ;;
            7) clean_docker_system ;;
            8) bash <(curl -sSL https://linuxmirrors.cn/docker.sh) ;;
            9)
                read -p "请输入最大日志大小(默认:20m): " max_size
                read -p "请输入保留的日志文件数(默认:3): " max_file
                setup_docker_logging "${max_size:-20m}" "${max_file:-3}"
                ;;
            10)
                echo "IPv6管理"
                echo "1. 开启IPv6"
                echo "2. 关闭IPv6"
                read -p "请选择: " ipv6_choice
                case $ipv6_choice in
                    1) docker_ipv6_on || handle_error "开启IPv6失败" ;;
                    2) docker_ipv6_off || handle_error "关闭IPv6失败" ;;
                    *) handle_error "无效的选择" ;;
                esac
                ;;
            11)
                echo "Docker性能监控"
                docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
                ;;
            12) check_docker_health ;;
            13) backup_docker ;;
            14) check_docker_security ;;
            50)
                if ask_confirmation "确定要卸载Docker吗?" "n"; then
                    uninstall_docker
                fi
                ;;
            0) 
                echo "感谢使用Docker管理系统"
                exit 0
                ;;
            *) handle_error "无效的选择" ;;
        esac
        [ "$choice" != "11" ] && break_end
    done
}

# 主程序入口
main() {
    # 检查是否为root用户
    if [ "$(id -u)" != "0" ]; then
        handle_error "此脚本需要root权限运行"
        exit 1
    fi

    # 处理命令行参数
    case "$1" in
        update) update_docker ;;
        state) state_docker ;;
        uninstall) uninstall_docker ;;
        manage) docker_manage ;;
        *)
            if [ -n "$1" ]; then
                echo "用法: $0 {update|state|uninstall|manage}"
                exit 1
            else
                docker_manage
            fi
            ;;
    esac
}

# 启动程序
main "$@"
