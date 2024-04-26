#!/bin/bash

# 函数：退出
break_end_docker() {
	echo -e "\033[0;32m操作完成\033[0m"
	echo "按任意键继续..."
	read -n 1 -s -r -p ""
	echo
	clear
}

# 检查Docker是否安装
check_docker_installed() {
    if ! command -v docker &>/dev/null; then
        echo "Docker 未安装。"
        return 1
    fi
}

# 函数：询问用户确认
ask_confirmation_docker() {
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

# 查看Docker全局状态逻辑
state_docker() {

    # 打印Docker版本
    echo "Docker 版本:"
    docker --version
    # 检查docker-compose是否安装
    if command -v docker-compose &>/dev/null; then
        docker-compose --version
    else
        echo "docker-compose 未安装。"
    fi
    echo "---------------------------------------------"

    # 打印Docker镜像列表
    echo "Docker 镜像列表:"
    docker image ls
    echo "---------------------------------------------"

    # 打印Docker容器列表
    echo "Docker 容器列表:"
    docker ps -a
    echo "---------------------------------------------"

    # 打印Docker卷列表
    echo "Docker 卷列表:"
    docker volume ls
    echo "---------------------------------------------"

    # 打印Docker网络列表
    echo "Docker 网络列表:"
    docker network ls
    echo "---------------------------------------------"
}

# 功能：获取容器名
get_container_name_docker() {
    read -p "请输入容器名: " dockername
    echo $dockername
}

# 功能：检查并创建网络
check_and_create_networks() {
    # 获取所有正在运行的容器ID
    local container_ids=$(docker ps -aq)

    # 声明一个关联数组以存储网络名称
    declare -A network_exists

    # 获取现有网络列表
    local existing_networks=$(docker network ls --format '{{.Name}}')
    for net in $existing_networks; do
        network_exists["$net"]=1
    done

    # 检查每个容器使用的网络，并确保它们存在
    for id in $container_ids; do
        # 使用正确的命令格式获取每个容器的网络名称
        local networks=$(docker inspect $id --format '{{range $key, $_ := .NetworkSettings.Networks}}{{$key}} {{end}}')
        for net_name in $networks; do
            if [ -z "${network_exists[$net_name]}" ]; then
                echo "网络 '$net_name' 不存在，正在创建..."
                if docker network create "$net_name"; then
                    echo "已创建网络: $net_name"
                    network_exists["$net_name"]=1
                else
                    echo "创建网络 '$net_name' 失败"
                fi
            fi
        done
    done
}

# 功能：执行 Docker 命令
execute_check_command() {
    local command="$1"
    local container_name_or_all="$2"  # 可以是单个容器的名称/ID，或者是 'all' 表示所有容器

    if [[ "$container_name_or_all" == "all" ]]; then
        # 对所有容器执行命令
        if [[ "$command" == "stop" || "$command" == "restart" ]]; then
            local containers=$(docker ps -q)
            if [ -z "$containers" ]; then
                echo "没有正在运行的容器，无法执行 $command 操作。"
                return 1  # 返回非零退出代码表示错误
            fi
            # 执行对所有容器的命令
            docker $command $containers
        else
            echo "命令 '$command' 不支持 'all' 选项。"
            return 1
        fi
    else
        # 对单个容器执行命令
        docker $command $container_name_or_all
    fi

    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo "操作成功。"
    else
        echo "操作失败，请检查容器名或ID是否正确。"
    fi
}

# 函数: 显示所有容器的网络信息
display_network_info() {
    local container_ids=$(docker ps -aq)  # 显示所有容器，包括非运行状态的容器
    printf "%-25s %-30s %-25s\n" "容器名称" "网络名称" "IP地址"  # 调整了网络名称列的宽度

    for container_id in $container_ids; do
        # 获取容器的名称和网络信息
        local container_info=$(docker inspect --format '{{ .Name }}{{ range $network, $config := .NetworkSettings.Networks }} {{ printf "%s %s" $network .IPAddress }}{{ end }}' $container_id | sed 's/^\///')

        # 分离出容器名称
        local container_name=$(echo "$container_info" | awk '{print $1}')

        # 分离出网络信息并处理每一条
        local network_info=$(echo "$container_info" | awk '{for (i=2; i<=NF; i+=2) print $i, $(i+1)}')
        while IFS= read -r line; do
            local network_name=$(echo "$line" | awk '{print $1}')
            local ip_address=$(echo "$line" | awk '{print $2}')
            printf "%-21s %-26s %-25s\n" "$container_name" "$network_name" "$ip_address"
        done <<< "$network_info"
    done
}

# Docker容器管理
docker_container_manage() {
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
                read -p "请输入创建命令: " docker_command
                eval $docker_command
                ;;						
             2|3|4|5)
                container_name=$(get_container_name_docker)
                case $sub_choice in
                    2)
                        check_and_create_networks
                        execute_check_command "start" $container_name
                        if docker ps | grep -q $container_name; then
                            echo "容器已成功启动。"
                        else
                            echo "容器启动失败。"
                        fi
                        ;;
                    3)
                        execute_check_command "stop" $container_name
                        if ! docker ps | grep -q $container_name; then
                            echo "容器已成功停止。"
                        else
                            echo "容器停止失败。"
                        fi
                        ;;
                    4)
                        execute_check_command "rm -f" $container_name
                        ;;
                    5)
                        execute_check_command "restart" $container_name
                        if docker ps | grep -q $container_name; then
                            echo "容器已成功重启。"
                        else
                            echo "容器重启失败。"
                        fi
                        ;;
                esac
                break_end_docker
                ;;
            6)
                docker start $(docker ps -a -q)
                break_end_docker
                ;;
            7)
                # docker stop $(docker ps -q)
                execute_check_command "stop" "all"
                break_end_docker
                ;;
            8)
                if ask_confirmation_docker "确定删除所有容器吗？"; then
                    docker rm -f $(docker ps -a -q) && echo "已删除所有容器。" || echo "删除操作失败。"
                else
                    echo "操作已取消。"
                fi
                break_end_docker
                ;;
            9)
                execute_check_command "restart" "all"
                break_end_docker
                ;;
            11)
                container_name=$(get_container_name_docker)
                docker exec -it $container_name /bin/bash
                break_end_docker
                ;;
            12)
                container_name=$(get_container_name_docker)
                docker logs $container_name
                break_end_docker
                ;;
            13)
                echo ""
                echo "------------------------------------------------------------"
                display_network_info  
                break_end_docker  
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

# docker 镜像管理
image_management() {
    # Dcoker镜像管理
    while true; do
        clear
        echo "Docker镜像列表"
        docker image ls
        echo ""
        echo "镜像操作"
        echo "------------------------"
        echo "1. 获取或更新指定镜像"
        echo "2. 删除指定镜像"
        echo "3. 删除所有镜像"
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
                if docker rmi -f $dockername; then
                    echo "镜像已删除。"
                else
                    echo "删除镜像失败。"
                fi
                ;;
            3)
                if ask_confirmation_docker "确定删除所有镜像吗？"; then
                    if [ -n "$(docker images -q)" ]; then  # 检查是否有镜像
                        docker rmi -f $(docker images -q)
                        echo "所有镜像已删除。"
                    else
                        echo "没有可删除的镜像。"  # 当不存在任何镜像时的提示
                    fi
                else
                    echo "操作已取消。"  # 用户取消操作的提示
                fi
                ;;
            0)
                break  # 跳出循环，退出菜单
                ;;

            *)
                break  # 跳出循环，退出菜单
                ;;
        esac
        break_end_docker
    done
}

# docker 网络管理
network_management() {
    # Dcoker网络管理
    while true; do
        clear
        echo "Docker网络列表"
        echo "------------------------------------------------------------"
        docker network ls
        echo ""
        echo "------------------------------------------------------------"
        display_network_info

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
                echo "$dockernetwork 网络已设置成功。"
                break_end_docker
                ;;
            2)
                read -p "加入网络名: " dockernetwork
                read -p "容器名称或ID: " dockername
                docker network connect $dockernetwork $dockername
                echo "容器已加入到 $dockernetwork 网络。"
                break_end_docker
                ;;
            3)
                read -p "退出网络名: " dockernetwork
                read -p "容器名称或ID: " dockername
                docker network disconnect $dockernetwork $dockername
                echo "容器已从 $dockernetwork 网络退出。"
                break_end_docker
                ;;
            4)
                read -p "请输入要删除的网络名: " dockernetwork
                # 检查是否有容器正在使用该网络
                local connected_containers=$(docker network inspect $dockernetwork --format '{{ range .Containers }}{{ .Name }} {{ end }}')
                if [[ -n "$connected_containers" ]]; then
                    echo "警告: 以下容器正在使用 $dockernetwork 网络: $connected_containers"
                    if ask_confirmation_docker "你确定要断开这些容器的网络连接并删除网络吗？"; then
                        for container in $connected_containers; do
                            docker network disconnect $dockernetwork $container
                        done
                        docker network rm $dockernetwork
                        echo "$dockernetwork 网络及其连接已被删除。"
                    else
                        echo "网络删除操作已取消。"
                    fi
                else
                    docker network rm $dockernetwork
                    echo "$dockernetwork 网络已删除。"
                fi
                break_end_docker
                ;;
            0)
                break  # 跳出循环，退出菜单
                ;;
            *)
                echo "无效选择，请重新输入。"
                ;;
        esac
    done
}

# docker 卷管理
volume_management() {
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
                if docker volume create "$dockerjuan"; then
                    echo "卷 '$dockerjuan' 创建成功。"
                else
                    echo "创建卷失败，请检查输入或权限。"
                fi
                ;;
            2)
                read -p "输入删除卷名: " dockerjuan
                read -p "确定要删除卷 '$dockerjuan' 吗？(Y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    if docker volume rm "$dockerjuan"; then
                        echo "卷 '$dockerjuan' 已删除。"
                    else
                        echo "删除卷失败，请检查卷名是否正确或是否正在使用。"
                    fi
                else
                    echo "取消删除操作。"
                fi
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

# 函数：列出并审查即将删除的 Docker 对象
review_prune_candidates() {
    echo "即将删除以下停止的容器："
    docker container ls -a --filter status=exited

    echo "即将删除以下悬空的镜像："
    docker images -f dangling=true

    echo "即将删除以下未使用的网络："
    echo "NETWORK ID    NAME                DRIVER              SCOPE"
    docker network ls --filter type=custom --format "{{.ID}}" | while read network_id
    do
        # 忽略在网络详情查找过程中的错误信息
        network_details=$(docker network inspect $network_id --format '{{.ID}} {{.Name}} {{.Driver}} {{.Scope}}' 2>/dev/null)
        if [[ -n $network_details ]]; then
            network_containers=$(docker network inspect $network_id --format '{{json .Containers}}')
            if [[ $network_containers == "{}" ]]; then
                echo "$network_details" | awk '{ printf "%-12s %-20s %-18s %-10s\n", substr($1,1,12), $2, $3, $4 }'
            fi
        fi
    done

    echo "即将删除以下未使用的数据卷："
    echo "VOLUME NAME"
    docker volume ls -f dangling=true --format "{{.Name}}"
}

# 清理无用的docker容器和镜像网络数据卷"
clean_volume_network_container() {
    # 清理无用的docker容器和镜像网络数据卷
    clear
    echo "请审查即将删除的 Docker 对象："
    review_prune_candidates

    if ask_confirmation_docker "确定要继续清理吗？"; then
        echo "正在清理，请稍候..."
        docker system prune -af --volumes
        echo "清理完成。"
    else
        echo "操作已取消。"
    fi
}

# 卸载Docker环境
uninstall_docker() {
    clear
    echo "此操作将完全卸载Docker环境，包括所有容器、镜像和网络配置。"
    read -p "确定卸载docker环境吗？(Y/N): " choice

    case "$choice" in
        [Yy])
            check_docker_installed
            
            echo "停止所有正在运行的容器..."
            docker stop $(docker ps -q) 2>/dev/null || true

            echo "删除所有容器..."
            docker rm $(docker ps -a -q) 2>/dev/null || true

            echo "删除所有镜像..."
            docker rmi $(docker images -q) 2>/dev/null || true

            echo "清除所有未使用的网络..."
            docker network prune -f 2>/dev/null || true

            # 根据安装的包管理器选择卸载命令
            if command -v apt-get &>/dev/null; then
                sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
                sudo apt-get autoremove -y
            elif command -v yum &>/dev/null; then
                sudo yum remove -y docker docker-client docker-client-latest docker-common \
                docker-latest docker-latest-logrotate docker-logrotate docker-engine
            elif command -v apk &>/dev/null; then
                sudo apk del docker docker-compose
            else
                echo "未识别的包管理器。"
                exit 1
            fi

            # 删除Docker数据目录
            sudo rm -rf /var/lib/docker /var/lib/containerd

            echo $PATH  # 查看当前PATH变量
            export PATH=$(echo $PATH | sed -e 's/:\/path\/to\/docker//')  # 移除docker路径

            echo "Docker已成功卸载。"
            ;;
        [Nn])
            echo "卸载操作已取消。"
            ;;
        *)
            echo "无效的选择，请输入 Y 或 N。"
            ;;
    esac
}

# Docker管理器
docker_manage() {
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
                clear
                update_docker
                break_end_docker
                ;;
            2)
                clear
                if check_docker_installed; then
                    state_docker
                    break_end_docker
                else
                    break_end_docker
                fi
                ;;
            3)
                clear
                if check_docker_installed; then
                    docker_container_manage
                else
                    break_end_docker
                fi
                ;;
            4)
                clear
                if check_docker_installed; then
                    image_management
                else
                    break_end_docker
                fi
                ;;
            5)
                clear
                if check_docker_installed; then
                    network_management
                else
                    break_end_docker
                fi
                ;;
            6)
                clear
                if check_docker_installed; then
                    volume_management
                else
                    break_end_docker
                fi
                ;;
            7)
                clear
                if check_docker_installed; then
                    clean_volume_network_container
                fi
                break_end_docker
                ;;
            8)
                clear
                uninstall_docker
                break_end_docker
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

# 主逻辑
case "$1" in
        update)
            update_docker
            ;;
        state)
            if check_docker_installed; then
                state_docker
            else
                echo "Docker is not installed."
            fi
            ;;
        uninstall)
            uninstall_docker
            ;;
        manage)
            docker_manage
            ;;
        *)
            echo "Usage: $0 {update|state|uninstall|manage}"
            exit 1
    esac
