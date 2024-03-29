#!/bin/bash
ln -sf ~/solin.sh /usr/local/bin/s

solin() {
	s
	exit
}

# 函数：退出
break_end() {
	echo -e "\033[0;32m操作完成\033[0m"
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
            if command -v apt &>/dev/null; then
                apt update -y && apt install -y "$package"
            elif command -v yum &>/dev/null; then
                yum -y update && yum -y install "$package"
            elif command -v apk &>/dev/null; then
                apk update && apk add "$package"
            else
                echo "未知的包管理器!"
                return 1
            fi
        fi
    done

    return 0
}

# 卸载软件
remove() {
    if [ $# -eq 0 ]; then
        echo "未提供软件包参数!"
        return 1
    fi

    for package in "$@"; do
        if command -v apt &>/dev/null; then
            apt purge -y "$package"
        elif command -v yum &>/dev/null; then
            yum remove -y "$package"
        elif command -v apk &>/dev/null; then
            apk del "$package"
        else
            echo "未知的包管理器!"
            return 1
        fi
    done

    return 0
}

# 函数: 获取IPv4和IPv6地址
ip_address() {
    ipv4_address=$(curl -s ipv4.ip.sb)
    ipv6_address=$(curl -s --max-time 1 ipv6.ip.sb)
}

# 函数: 获取网络接收和发送流量
network_traffic() {
    # 使用 awk 从 /proc/net/dev 读取每个接口的接收和发送字节数，并进行累加
    read rx_total tx_total < <(awk '{if ($1 ~ /^[a-zA-Z0-9]+:$/) {rx+=$2; tx+=$10}} END {print rx, tx}' /proc/net/dev)

    # 初始化单位为 Bytes
    rx_units="Bytes"
    tx_units="Bytes"

    # 调用 convert_unit 函数来转换单位
    convert_unit rx_total rx_units
    convert_unit tx_total tx_units

    # 构造输出字符串
    network_output="总接收: $rx_total $rx_units  总发送: $tx_total $tx_units"
}

# 函数: 单位转换
convert_unit() {
    local -n value_ref=$1
    local -n unit_ref=$2

    # 如果值大于 1 GB
    if ((value_ref >= 1024**3)); then
        unit_ref="GB"
        local gb=$((value_ref / 1024**3))
        local remainder=$((value_ref % 1024**3))
        local decimal=$((remainder / (1024**2 / 10)))
        value_ref="${gb}.${decimal}"
    # 如果值大于 1 MB
    elif ((value_ref >= 1024**2)); then
        unit_ref="MB"
        local mb=$((value_ref / 1024**2))
        local remainder=$((value_ref % 1024**2))
        local decimal=$((remainder / (1024 / 10)))
        value_ref="${mb}.${decimal}"
    # 如果值大于 1 KB
    elif ((value_ref >= 1024)); then
        unit_ref="KB"
        local kb=$((value_ref / 1024))
        local remainder=$((value_ref % 1024))
        local decimal=$((remainder / (10)))
        value_ref="${kb}.${decimal}"
    fi
    # 如果值小于 1 KB，则保持 Bytes 单位，不需要转换
}

# 函数: 显示系统信息
show_system_info() {
    clear
    # 获取IP地址
    ip_address

    # 获取CPU信息
    cpu_info=$(awk -F ': ' '/model name/ {print $2; exit}' /proc/cpuinfo)
    cpu_usage_percent=$(awk '/^%Cpu/ {print int($2)}' <(top -bn1))
    cpu_cores=$(nproc)
    mem_info=$(free -m | awk '/Mem:/ {printf "%.2f/%.2f MB (%.2f%%)", $3, $2, $3*100/$2 }')
    disk_info=$(df -h | awk '$NF=="/"{printf "%s/%s (%s)", $3, $2, $5}')
    network_traffic

    # 获取其他系统信息
    isp_info=$(curl -s ipinfo.io/org)
    cpu_arch=$(uname -m)
    hostname=$(hostname)
    kernel_version=$(uname -r)
    congestion_algorithm=$(sysctl -n net.ipv4.tcp_congestion_control)
    queue_algorithm=$(sysctl -n net.core.default_qdisc)
    os_info=$(awk -F= '/^PRETTY_NAME/ {print $2}' /etc/os-release | tr -d '"')
    current_time=$(date "+%Y-%m-%d %I:%M %p")
    swap_info=$(free -m | awk '/Swap:/ {printf "%dMB/%dMB (%.2f%%)", $3, $2, $3*100/$2 }')
    runtime=$(awk '{printf "%d天 %d小时 %d分钟\n", int($1/86400), int(($1%86400)/3600), int(($1%3600)/60)}' /proc/uptime)

    # 输出系统信息
    cat << EOF
系统信息查询
------------------------
主机名: $hostname
运营商: $isp_info
------------------------
系统版本: $os_info
Linux版本: $kernel_version
------------------------
CPU架构: $cpu_arch
CPU型号: $cpu_info
CPU核心数: $cpu_cores
CPU占用: ${cpu_usage_percent}%
物理内存: $mem_info
虚拟内存: $swap_info
硬盘占用: $disk_info
------------------------
$network_output
------------------------
网络拥堵算法: $congestion_algorithm $queue_algorithm
------------------------
公网IPv4地址: $ipv4_address
公网IPv6地址: $ipv6_address
------------------------
系统时间: $current_time
系统运行时长: $runtime
EOF
}

# 函数：更新系统
update_service() {
    echo "开始更新系统..."
    # Update system on Debian-based systems
    if [ -f "/etc/debian_version" ]; then
        apt update -y && DEBIAN_FRONTEND=noninteractive apt full-upgrade -y
    fi

    # Update system on Red Hat-based systems
    if [ -f "/etc/redhat-release" ]; then
        yum -y update
    fi

    # Update system on Alpine Linux
    if [ -f "/etc/alpine-release" ]; then
        apk update && apk upgrade
    fi
}

# 清理Debian系统
clean_debian() {
    # 确保脚本以root权限运行
    if [ "$(id -u)" != "0" ]; then
        echo "错误：此脚本需要以root权限运行。"
        return 1
    fi

    # 移除不再需要的包和配置文件
    if ! apt-get autoremove --purge -y; then
        echo "移除不再需要的包和配置文件失败。"
        return 1
    fi

    # 清理本地已下载的包文件的存档
    if ! apt-get clean -y; then
        echo "清理本地已下载的包文件的存档失败。"
        return 1
    fi

    # 清理仓库中不再下载的包的存档
    if ! apt-get autoclean -y; then
        echo "清理仓库中不再下载的包的存档失败。"
        return 1
    fi

    # 移除残留配置文件
    residual_config=$(dpkg -l | awk '/^rc/ {print $2}')
    if [ -n "$residual_config" ]; then
        if ! apt-get remove --purge $residual_config -y; then
            echo "移除残留配置文件失败。"
            return 1
        fi
    fi

    # 清理日志
    if ! journalctl --rotate; then
        echo "日志轮转失败。"
        return 1
    fi
    if ! journalctl --vacuum-time=1s; then
        echo "清理日志时间戳失败。"
        return 1
    fi
    if ! journalctl --vacuum-size=50M; then
        echo "清理日志大小失败。"
        return 1
    fi

    # 移除旧的Linux内核
    old_kernels=$(dpkg -l | awk '/^ii linux-(image|headers)-[^ ]+/ {print $2}' | grep -v $(uname -r | cut -d'-' -f1))
    if [ -n "$old_kernels" ]; then
        if ! apt-get remove --purge $old_kernels -y; then
            echo "移除旧的Linux内核失败。"
            return 1
        fi
    fi

    echo "系统清理完成。"
    return 0
}

# 清理Red Hat-based systems系统
clean_redhat() {
    # 确保脚本以root权限运行
    if [ "$(id -u)" != "0" ]; then
        echo "错误：此脚本需要以root权限运行。"
        return 1
    fi

    # 移除不再需要的包
    if ! yum autoremove -y; then
        echo "移除不再需要的包失败。"
        return 1
    fi

    # 清理所有的缓存
    if ! yum clean all; then
        echo "清理yum缓存失败。"
        return 1
    fi

    # 清理日志
    if ! journalctl --vacuum-time=1s; then
        echo "清理旧日志失败。"
        return 1
    fi
    if ! journalctl --vacuum-size=50M; then
        echo "限制日志大小失败。"
        return 1
    fi

    # 移除旧的Linux内核
    old_kernels=$(rpm -q kernel | grep -v $(uname -r))
    if [ -n "$old_kernels" ]; then
        if ! yum remove $old_kernels -y; then
            echo "移除旧的Linux内核失败。"
            return 1
        fi
    fi

    echo "系统清理完成。"
    return 0
}

# 清理alpine系统
clean_alpine() {
    # 获取所有已安装的包
    local installed_pkgs=$(apk info --installed | awk '{print $1}')
    # 获取所有可用的包
    local available_pkgs=$(apk info --available | awk '{print $1}')
    # 确定哪些已安装的包不在可用的包列表中
    local pkgs_to_remove=$(echo "${installed_pkgs}" | grep -v -F -x -e "${available_pkgs}")

    # 如果有要删除的包，则删除它们
    if [ -n "${pkgs_to_remove}" ]; then
        echo "Removing packages not available in the apk repositories:"
        echo "${pkgs_to_remove}"
        apk del --purge ${pkgs_to_remove}
    else
        echo "No packages to remove."
    fi

    # 移除不再需要的依赖包
    apk autoremove
    
    # 清理apk缓存
    apk cache clean
    
    # 安全地删除/var/log下的文件和/var/cache/apk下的文件
    if [ -d "/var/log" ]; then
        echo "Cleaning /var/log"
        rm -rf /var/log/*
    fi
    
    if [ -d "/var/cache/apk" ]; then
        echo "Cleaning /var/cache/apk"
        rm -rf /var/cache/apk/*
    fi
}

# 清理系统垃圾
clean_service() {
    echo "开始清理系统垃圾..."

    # 确保脚本以root权限运行
    if [ "$(id -u)" != "0" ]; then
        echo "错误：此脚本需要以root权限运行。"
        return 1
    fi

    # 判断系统类型并执行相应的清理
    if [ -f "/etc/debian_version" ]; then
        if [ -f "/etc/redhat-release" ]; then
            echo "警告：系统同时检测到Debian和Red Hat标识。请手动选择要执行的清理操作。"
            return 1
        else
            clean_debian
        fi
    elif [ -f "/etc/redhat-release" ]; then
        clean_redhat
    elif [ -f "/etc/alpine-release" ]; then
        clean_alpine
    else
        echo "未能识别的系统类型或系统不支持。"
        return 1
    fi
}

# 常用工具
common_tool() {
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
                ;;
            2)
                clear
                install wget
                clear
                echo "工具已安装，使用方法如下："
                wget --help
                ;;
            3)
                clear
                install sudo
                clear
                echo "工具已安装，使用方法如下："
                sudo --help
                ;;
            4)
                clear
                install socat
                clear
                echo "工具已安装，使用方法如下："
                socat -h
                ;;
            5)
                clear
                install htop
                clear
                htop
                ;;
            6)
                clear
                install iftop
                clear
                iftop
                ;;
            7)
                clear
                install unzip
                clear
                echo "工具已安装，使用方法如下："
                unzip
                ;;
            8)
                clear
                install tar
                clear
                echo "工具已安装，使用方法如下："
                tar --help
                ;;
            9)
                clear
                install tmux
                clear
                echo "工具已安装，使用方法如下："
                tmux --help
                ;;
            10)
                clear
                install ffmpeg
                clear
                echo "工具已安装，使用方法如下："
                ffmpeg --help
                ;;

            11)
                clear
                install btop
                clear
                btop
                ;;
            12)
                clear
                install ranger
                cd /
                clear
                ranger
                cd ~
                ;;
            13)
                clear
                install gdu
                cd /
                clear
                gdu
                cd ~
                ;;
            14)
                clear
                install fzf
                cd /
                clear
                fzf
                cd ~
                ;;
            31)
                clear
                install curl wget sudo socat htop iftop unzip tar tmux ffmpeg btop ranger gdu fzf
                ;;

            32)
                clear
                remove htop iftop unzip tmux ffmpeg btop ranger gdu fzf
                ;;

            41)
                clear
                read -p "请输入安装的工具名（wget curl sudo htop）: " installname
                install $installname
                ;;
            42)
                clear
                read -p "请输入卸载的工具名（htop ufw tmux）: " removename
                remove $removename
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

}

#BBR脚本
bbr_script() {
    clear
    if [ -f "/etc/alpine-release" ]; then
        while true; do
            clear
            congestion_algorithm=$(sysctl -n net.ipv4.tcp_congestion_control)
            queue_algorithm=$(sysctl -n net.core.default_qdisc)
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
                    cat > /etc/sysctl.conf << EOF
net.core.default_qdisc=fq_pie
net.ipv4.tcp_congestion_control=bbr
EOF
                    sysctl -p
                    ;;
                2)
                    sed -i '/net.core.default_qdisc=fq_pie/d' /etc/sysctl.conf
                    sed -i '/net.ipv4.tcp_congestion_control=bbr/d' /etc/sysctl.conf
                    sysctl -p
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
        install wget
        wget --no-check-certificate -O tcpx.sh https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcpx.sh
        chmod +x tcpx.sh
        ./tcpx.sh
    fi
}

# 定义安装更新 Docker 的函数
update_docker() {
    if [ -f "/etc/alpine-release" ]; then
        apk update
        apk add docker docker-compose
        rc-update add docker default
        service docker start
    else
        curl -fsSL https://get.docker.com | sh && ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin
        systemctl start docker
        systemctl enable docker
    fi
}

# 定义安装 Docker 的函数
install_docker() {
    if ! command -v docker &>/dev/null; then
        update_docker
    else
        echo "Docker 已经安装"
    fi
}

# 查看Docker全局状态逻辑
check_docker() {
    # 检查Docker是否安装
    if ! command -v docker &>/dev/null; then
        echo "Docker 未安装。"
        return 1
    fi

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
                    # 使用docker inspect一次性获取所有信息
                    container_info=$(docker inspect --format '{{ .Name }}{{ range .NetworkSettings.Networks }} {{ . }}{{ end }}' "$container_id")

                    # 从container_info中提取容器名称
                    container_name=$(echo "$container_info" | awk '{print $1}' | sed 's/^\///') # 移除容器名称前的斜杠

                    # 使用数组存储网络信息
                    readarray -t network_info <<< "$(echo "$container_info" | awk '{$1=""; print substr($0, 2)}')"

                    # 遍历网络信息
                    for net_info in "${network_info[@]}"; do
                        network_name=$(echo "$net_info" | awk '{print $1}')
                        ip_address=$(echo "$net_info" | awk '{print $2}')

                        printf "%-25s %-25s %-25s\n" "$container_name" "$network_name" "$ip_address"
                    done
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
}

# 清理无用的docker容器和镜像网络数据卷"
clean_volume_network_container() {
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
}

# 卸载Docker环境
uninstall_docker() {
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
            elif [ -f "/etc/alpine-release" ]; then
                # 对于Alpine Linux，使用apk来卸载Docker
                sudo apk del docker docker-compose
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
                ;;
            2)
                clear
                check_docker
                ;;
            3)
                clear
                docker_container_manage
                ;;
            4)
                clear
                image_management
                ;;
            5)
                clear
                network_management
                ;;
            6)
                clear
                volume_management
                ;;
            7)
                clear
                clean_volume_network_container
                ;;
            8)
                clear
                uninstall_docker
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
}

# 测试脚本
test_script() {
    while true; do
        clear
        echo "▶ 测试脚本合集"
        echo "------------------------"
        echo "1. ChatGPT解锁状态检测"
        echo "2. Region流媒体解锁测试"
        echo "3. yeahwu流媒体解锁检测"
        echo "4. besttrace三网回程延迟路由测试"
        echo "5. mtr_trace三网回程线路测试"
        echo "6. Superspeed三网测速"
        echo "7. yabs性能带宽测试"
        echo "8. bench性能测试"
        echo "------------------------"
        echo -e "9. spiritysdx融合怪测评 \033[33mNEW\033[0m"
        echo "------------------------"
        echo "0. 返回主菜单"
        echo "------------------------"
        read -p "请输入你的选择: " sub_choice

        case $sub_choice in
            1)
                clear
                bash <(curl -Ls https://cdn.jsdelivr.net/gh/missuo/OpenAI-Checker/openai.sh)
                ;;
            2)
                clear
                bash <(curl -L -s check.unlock.media)
                ;;
            3)
                clear
                install wget
                wget -qO- https://github.com/yeahwu/check/raw/main/check.sh | bash
                ;;
            4)
                clear
                install wget
                wget -qO- git.io/besttrace | bash
                ;;
            5)
                clear
                curl https://raw.githubusercontent.com/zhucaidan/mtr_trace/main/mtr_trace.sh | bash
                ;;
            6)
                clear
                bash <(curl -Lso- https://git.io/superspeed_uxh)
                ;;
            7)
                clear
                curl -sL yabs.sh | bash -s -- -i -5
                ;;
            8)
                clear
                curl -Lso- bench.sh | bash
                ;;
            9)
                clear
                curl -L https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh -o ecs.sh && chmod +x ecs.sh && bash ecs.sh
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

}

# 设置root密码
set_rootpasswd() {

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
        0)
            solin
            ;;
        *)
            echo "无效的选择，请输入 Y 或 N。"
            ;;
    esac
}

# DD系统1
dd_xitong_1() {    
    read -p "请输入你重装后的密码: " vpspasswd
    echo "任意键继续，重装后初始用户名: root  初始密码: $vpspasswd  初始端口: 22"
    read -n 1 -s -r -p ""
    install wget
    bash <(wget --no-check-certificate -qO- 'https://raw.githubusercontent.com/MoeClub/Note/master/InstallNET.sh') $xitong -v 64 -p $vpspasswd -port 22
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
                read -p "确定安装吗？(Y/N): " choice
                case "$choice" in
                    [Yy])
                        install_docker
                        docker run -itd --name=lookbusy --restart=always \
                                -e TZ=Asia/Shanghai \
                                -e CPU_UTIL=10-20 \
                                -e CPU_CORE=1 \
                                -e MEM_UTIL=15 \
                                -e SPEEDTEST_INTERVAL=120 \
                                fogforest/lookbusy
                        ;;
                    [Nn])
                        ;;
                    *)
                        echo "无效的选择，请输入 Y 或 N。"
                        ;;
                esac
                ;;
            2)
                clear
                docker rm -f lookbusy
                docker rmi fogforest/lookbusy
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
                solin
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

# 定义检测端口
check_port() {
    # 如果未传递端口参数，则默认为443
    local PORT=${1:-443}

    # 检查端口占用情况
    local result=$(ss -lntu | grep -w ":$PORT")

    # 判断结果并输出相应信息
    if [ -n "$result" ]; then
        # 直接使用docker ps的过滤器来检查是否是Nginx容器占用端口
        local is_nginx_container=$(docker ps -f "ancestor=nginx" --format '{{.Names}}')

        if [ -n "$is_nginx_container" ]; then
            echo "端口 $PORT 被以下 Nginx 容器占用：$is_nginx_container"
        else
            echo -e "\e[1;31m端口 $PORT 已被占用，无法安装环境。请检查以下占用进程：\e[0m"
            echo "$result"
			break_end
            solin
        fi
    else
        echo "端口 $PORT 当前未被占用。"
    fi
}

# 安装依赖
install_dependency() {
    clear
    install wget socat unzip tar curl
}

# 调用函数来安装 Certbot 和设置 cron 任务
install_certbot() {
    install certbot

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

# SSL自签名
default_server_ssl() {
    install openssl
    openssl req -x509 -nodes -newkey rsa:2048 -keyout /home/docker/web/certs/default_server.key -out /home/docker/web/certs/default_server.crt -days 5475 -subj "/C=US/ST=State/L=City/O=Organization/OU=Organizational Unit/CN=Common Name"

}

# nginx 配置
nginx_config() {
   # 创建必要的目录和文件
    mkdir -p /home/docker && cd /home/docker && mkdir -p html web/certs web/conf.d web/log/nginx && touch web/docker-compose-nginx.yml
    wget -O /home/docker/web/nginx.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/LDNMP/nginx.conf
    wget -O /home/docker/web/conf.d/default.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/LDNMP/default.conf
    default_server_ssl
    docker rm -f nginx >/dev/null 2>&1
    docker rmi nginx >/dev/null 2>&1

    wget -O /home/docker/web/docker-compose-nginx.yml https://raw.githubusercontent.com/zxl2008gz/docker/main/LDNMP/docker-compose-nginx.yml
    
}

# 安装 nginx
install_nginx() {
    nginx_config
    cd /home/docker/web && docker-compose -f docker-compose-nginx.yml up -d
}

# 创建必要的目录和文件
create_mysql_redis_php_file() {

    # 创建必要的目录和文件
    mkdir -p /home/docker && cd /home/docker && mkdir -p html mysql redis && touch docker-compose-mysql_redis_php.yml

    # 下载 docker-compose.yml 文件并进行替换
    wget -O /home/docker/docker-compose-mysql_redis_php.yml https://raw.githubusercontent.com/zxl2008gz/docker/main/LDNMP/docker-compose-mysql_redis_php.yml

    install openssl
    dbrootpasswd=$(openssl rand -base64 16) && dbuse=$(openssl rand -hex 4) && dbusepasswd=$(openssl rand -base64 8)

    # 在 docker-compose.yml 文件中进行替换
    sed -i "s|mysqlwebroot|$dbrootpasswd|g" /home/docker/docker-compose-mysql_redis_php.yml
    sed -i "s|mysqlpasswd|$dbusepasswd|g" /home/docker/docker-compose-mysql_redis_php.yml
    sed -i "s|mysqluse|$dbuse|g" /home/docker/docker-compose-mysql_redis_php.yml
}

# 安装mysql_redis_php
install_prm() {
    create_mysql_redis_php_file
    cd /home/docker && docker-compose -f docker-compose-mysql_redis_php.yml up -d
}

# 仅安装nginx
nginx_display() {

    clear
    nginx_version=$(docker exec nginx nginx -v 2>&1)
    nginx_version=$(echo "$nginx_version" | grep -oP "nginx/\K[0-9]+\.[0-9]+\.[0-9]+")
    echo "nginx已安装完成"
    echo "当前版本: v$nginx_version"
    echo ""
}

# 创建必要的目录和文件
create_ldnmp_file() {
    nginx_config
    create_mysql_redis_php_file
    # 输出一个空行到目标文件
    echo "" >> /home/docker/web/docker-compose-nginx.yml

    # 追加经过筛选的内容（除去第一行和包含'version:'的行）
    sed -n '/services:/,$p' /home/docker/docker-compose-mysql_redis_php.yml | sed '1d' | sed '/version:/d' >> /home/docker/web/docker-compose-nginx.yml

    # 复制修改后的文件，并重命名
    cp /home/docker/web/docker-compose-nginx.yml /home/docker/docker-compose.yml
    cd /home/docker && docker-compose up -d
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

# 获取ldnmp的信息
ldnmp_info() {
    # 获取nginx版本
    nginx_version=$(docker exec nginx nginx -v 2>&1)
    nginx_version=$(echo "$nginx_version" | grep -oP "nginx/\K[0-9]+\.[0-9]+\.[0-9]+")
    echo -n "nginx : v$nginx_version"

    # 获取mysql版本
    dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/docker/docker-compose.yml | tr -d '[:space:]')
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

# 添加域名
add_yuming() {
      ip_address
      echo -e "先将域名解析到本机IP: \033[33m$ipv4_address  $ipv6_address\033[0m"
      read -p "请输入你解析的域名: " yuming
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

# 获取SSL
install_ssltls() {
      docker stop nginx > /dev/null 2>&1
      iptables_open
      cd ~
      certbot certonly --standalone -d $yuming --email your@email.com --agree-tos --no-eff-email --force-renewal
      cp /etc/letsencrypt/live/$yuming/cert.pem /home/docker/web/certs/${yuming}_cert.pem
      cp /etc/letsencrypt/live/$yuming/privkey.pem /home/docker/web/certs/${yuming}_key.pem
      docker start nginx > /dev/null 2>&1
}

# 添加数据库
add_db() {
    # 从函数参数接收项目名称和文件路径
    name="$1"
    docker_compose_file="$2"

    # 检查docker-compose文件是否存在
    if [ ! -f "$docker_compose_file" ]; then
        echo "Docker compose文件不存在: $docker_compose_file"
        return 1
    fi

    # 根据传入的名称生成数据库名
    # 如果传入的是域名，则去除特殊字符；否则直接使用项目名称
    dbname=$(echo "$name" | sed -e 's/[^A-Za-z0-9]/_/g')

    # 从docker-compose.yml文件中提取数据库相关信息
    dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' "$docker_compose_file" | tr -d '[:space:]')
    dbuse=$(grep -oP 'MYSQL_USER:\s*\K.*' "$docker_compose_file" | tr -d '[:space:]')
    dbusepasswd=$(grep -oP 'MYSQL_PASSWORD:\s*\K.*' "$docker_compose_file" | tr -d '[:space:]')

    # 创建数据库和授权
    docker exec mysql mysql -u root -p"$dbrootpasswd" -e "CREATE DATABASE IF NOT EXISTS $dbname; GRANT ALL PRIVILEGES ON $dbname.* TO '$dbuse'@'%'; FLUSH PRIVILEGES;"
}

# 设置反向代理
reverse_proxy() {
    ip_address
    wget -O /home/docker/web/conf.d/$yuming.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/reverse-proxy.conf
    sed -i "s/yuming.com/$yuming/g" /home/docker/web/conf.d/$yuming.conf
    sed -i "s/0.0.0.0/$ipv4_address/g" /home/docker/web/conf.d/$yuming.conf
    sed -i "s/0000/$docker_port/g" /home/docker/web/conf.d/$yuming.conf

    docker restart nginx
}

# 设置网络名称
set_network_name() {
    local path="$1"
    
    # 获取目录名称
    dir_name=$(basename "$(dirname "$path")")
    
    # 构造默认网络名称
    network_name="${dir_name}_default"
}

# 重启LDNMP
restart_ldnmp() {

    docker exec nginx chmod -R 777 /var/www/html
    docker exec php chmod -R 777 /var/www/html
    docker exec php74 chmod -R 777 /var/www/html

    docker restart nginx
    docker restart php
    docker restart php74

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
}

# nginx的状态
nginx_status() {

    sleep 1

    nginx_container_name="nginx"

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

        dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/docker/docker-compose.yml | tr -d '[:space:]')
        docker exec mysql mysql -u root -p"$dbrootpasswd" -e "DROP DATABASE $dbname;" 2> /dev/null

        echo -e "\e[1;31m检测到域名证书申请失败，请检测域名是否正确解析或更换域名重新尝试！\e[0m"
    fi

}

# 添加kodbox 配置
kodbox_config() {
    wget -O /home/docker/web/conf.d/$yuming.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/kodbox/kodbox.com.conf
    sed -i "s/yuming.com/$yuming/g" /home/docker/web/conf.d/$yuming.conf

    cd /home/docker/html
    mkdir $yuming
    cd $yuming

    wget https://github.com/kalcaddle/kodbox/archive/refs/tags/1.49.10.zip
    unzip -o 1.49.10.zip
    rm 1.49.10.zip
}

# kodbox 显示
kodbox_display() {
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
}

# 添加dujiaoka 配置
dujiaoka_config() {

    wget -O /home/docker/web/conf.d/$yuming.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/dujiaoka/dujiaoka.com.conf

    sed -i "s/yuming.com/$yuming/g" /home/docker/web/conf.d/$yuming.conf

    cd /home/docker/html
    mkdir $yuming
    cd $yuming

    wget https://github.com/assimon/dujiaoka/releases/download/2.0.6/2.0.6-antibody.tar.gz && tar -zxvf 2.0.6-antibody.tar.gz && rm 2.0.6-antibody.tar.gz

}

# dujiaoka 显示
dujiaoka_display() {
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
    echo "sed -i 's/ADMIN_HTTPS=false/ADMIN_HTTPS=true/g' /home/docker/html/$yuming/dujiaoka/.env"
}

# 添加cms 配置
cms_config() {

    wget -O /home/docker/web/conf.d/$yuming.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/CMS/maccms.com.conf

    sed -i "s/yuming.com/$yuming/g" /home/docker/web/conf.d/$yuming.conf

    cd /home/docker/html
    mkdir $yuming
    cd $yuming

    wget https://github.com/magicblack/maccms_down/raw/master/maccms10.zip && unzip maccms10.zip && rm maccms10.zip
    cd /home/docker/html/$yuming/template/ && wget https://github.com/zxl2008gz/docker/raw/main/CMS/DYXS2.zip && unzip DYXS2.zip && rm /home/docker/html/$yuming/template/DYXS2.zip
    cp /home/docker/html/$yuming/template/DYXS2/asset/admin/Dyxs2.php /home/docker/html/$yuming/application/admin/controller
    cp /home/docker/html/$yuming/template/DYXS2/asset/admin/dycms.html /home/docker/html/$yuming/application/admin/view/system
    mv /home/docker/html/$yuming/admin.php /home/docker/html/$yuming/vip.php && wget -O /home/docker/html/$yuming/application/extra/maccms.php https://raw.githubusercontent.com/zxl2008gz/docker/main/CMS/maccms.php

}

# cms 显示
cms_display() {
    clear
    echo "您的苹果CMS搭建好了！"
    echo "https://$yuming"
    echo "------------------------"
    echo "安装信息如下: "
    echo "数据库地址: mysql"
    echo "数据库端口: 3306"
    echo "数据库名: $dbname"
    echo "用户名: $dbuse"
    echo "密码: $dbusepasswd"
    echo "数据库前缀: mac_"
    echo "------------------------"
    echo "安装成功后登录后台地址"
    echo "https://$yuming/vip.php"
}

# 添加flarum 配置
flarum_config() {

    wget -O /home/docker/web/conf.d/$yuming.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/flarum/flarum.com.conf

    sed -i "s/yuming.com/$yuming/g" /home/docker/web/conf.d/$yuming.conf

    cd /home/docker/html
    mkdir $yuming
    cd $yuming

    docker exec php sh -c "php -r \"copy('https://getcomposer.org/installer', 'composer-setup.php');\""
    docker exec php sh -c "php composer-setup.php"
    docker exec php sh -c "php -r \"unlink('composer-setup.php');\""
    docker exec php sh -c "mv composer.phar /usr/local/bin/composer"

    docker exec php composer create-project flarum/flarum /var/www/html/$yuming
    docker exec php sh -c "cd /var/www/html/$yuming && composer require flarum-lang/chinese-simplified"
    docker exec php sh -c "cd /var/www/html/$yuming && composer require fof/polls"
}

# flarum 显示
flarum_display() {
    clear
    echo "您的flarum论坛网站搭建好了！"
    echo "https://$yuming"
    echo "------------------------"
    echo "安装信息如下: "
    echo "数据库地址: mysql"
    echo "数据库名: $dbname"
    echo "用户名: $dbuse"
    echo "密码: $dbusepasswd"
    echo "表前缀: flarum_"
    echo "管理员信息自行设置"
}

# cloudreve 配置
cloudreve_config() {
    cd /home/ && mkdir -p docker/cloud && cd docker/cloud && mkdir temp_data && mkdir -vp cloudreve/{uploads,avatar} && touch cloudreve/conf.ini && touch cloudreve/cloudreve.db && mkdir -p aria2/config && mkdir -p data/aria2 && chmod -R 777 data/aria2
    curl -o /home/docker/cloud/docker-compose.yml https://raw.githubusercontent.com/zxl2008gz/docker/main/cloudreve/cloudreve-docker-compose.yml
    timeout=20
    docker_name="cloudreve"
    read -t $timeout -p "外部端口（默认输入：5212）" project_port
    docker_port=${project_port:-5212}
    [ -z "$project_port" ] && echo "" 
    sed -i "s/5212:5212/$docker_port:5212/g" /home/docker/cloud/docker-compose.yml
    cd /home/docker/cloud/ && docker-compose up -d
}

# 获取cloudreve 端口
get_cloudreve_port() {
    cloudreve_path="/home/docker/cloud/docker-compose.yml"
    port_number=$(grep -A 5 "cloudreve:" "$cloudreve_path" | grep "ports:" -A 1 | tail -n1 | awk -F ':' '{print $1}' | tr -d '[:space:]"-')
}

install_cloudreve() {
    
    mysql_redis_php_path="$1"

    if docker inspect cloudreve &>/dev/null; then
        clear
        echo "cloudreve已安装，访问地址: "
        ip_address
        get_cloudreve_port
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

                check_path_and_output $mysql_redis_php_path

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

                check_path_and_output $mysql_redis_php_path

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

# 自定义静态站点
custom_static() {

    wget -O /home/docker/web/conf.d/$yuming.conf https://raw.githubusercontent.com/zxl2008gz/docker/main/html.conf
    sed -i "s/yuming.com/$yuming/g" /home/docker/web/conf.d/$yuming.conf

    cd /home/docker/html
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
        dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/docker/docker-compose.yml | tr -d '[:space:]')
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
                ;;
            4)
                install goaccess
                goaccess --log-format=COMBINED /home/docker/web/log/nginx/access.log
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
                dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/docker/docker-compose.yml | tr -d '[:space:]')
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
                latest_tar=$(ls -t /home/docker/*.tar.gz | head -1)
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

# 站点防御
site_defense_program() {
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
        elif [ -f /etc/alpine-release ]; then
            # Alpine系统
            apk update
            apk add fail2ban
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
        
        install_nginx

        # 获取宿主机当前时区
        HOST_TIMEZONE=$(timedatectl show --property=Timezone --value)

        # 调整多个容器的时区
        docker exec -it nginx ln -sf "/usr/share/zoneinfo/$HOST_TIMEZONE" /etc/localtime
        docker exec -it php ln -sf "/usr/share/zoneinfo/$HOST_TIMEZONE" /etc/localtime
        docker exec -it php74 ln -sf "/usr/share/zoneinfo/$HOST_TIMEZONE" /etc/localtime
        docker exec -it mysql ln -sf "/usr/share/zoneinfo/$HOST_TIMEZONE" /etc/localtime
        docker exec -it redis ln -sf "/usr/share/zoneinfo/$HOST_TIMEZONE" /etc/localtime
        rm -rf /home/docker/web/log/nginx/*
        docker restart nginx

        curl -sS -O https://raw.githubusercontent.com/zxl2008gz/sh/main/nginx.local
        systemctl restart fail2ban
        sleep 1
        fail2ban-client status
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
                sed -i 's/worker_connections.*/worker_connections 131072;/' /home/docker/web/nginx.conf

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

# LDNMP环境
install_ldnmp() {

    while true; do
        clear
        echo -e "\033[33m5. LDNMP建站 ▶ \033[0m"
        echo "------------------------"
        echo "1. 安装LDNMP环境-Nginx"
        echo "------------------------"				
        echo "2. 安装WordPress"
        echo "------------------------"
        echo "3. 安装可道云桌面"
        echo "4. 安装onlyoffice可道云版本"
        echo "5. 安装独角数发卡网"
        echo "6. 安装苹果CMS网站"
        echo "7. 安装flarum论坛网站"
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
        echo "61. 仅安装nginx"	
        echo "62. 站点重定向"
        echo "63. 站点反向代理"
        echo "64. 自定义静态站点"				
        echo "------------------------"	
        echo "71. 站点数据管理                72. 备份全站数据"		
        echo "73. 定时远程备份                74. 还原全站数据"					
        echo "------------------------"
        echo "75. 站点防御程序"		
        echo "------------------------"
        echo "76. 优化LDNMP环境"					
        echo "77. 更新LDNMP环境"					
        echo "78. 卸载LDNMP环境"					
        echo "------------------------"				
        echo "0. 返回主菜单"
        echo "------------------------"
        read -p "请输入你的选择: " sub_choice

        case $sub_choice in
            1)
                check_port
                install_dependency
                install_docker
                install_certbot
                create_ldnmp_file
                clear
                echo "正在配置LDNMP环境，请耐心稍等……"
                docker exec nginx chmod -R 777 /var/www/html
                docker restart nginx > /dev/null 2>&1
                install_php
                clear
                echo "LDNMP环境安装完毕"
                echo "------------------------"
                ldnmp_info
                ;;
            2)
                clear
                add_yuming
                install_ssltls
                add_db "$yuming" "/home/docker/docker-compose.yml" 
                wordpress_config
                restart_ldnmp
                wordpress_display
                nginx_status
                ;;
            3)
                clear
                add_yuming
                install_ssltls
                add_db "$yuming" "/home/docker/docker-compose.yml"
                kodbox_config
                restart_ldnmp
                kodbox_display
                nginx_status
                ;;
            4)
                clear
                add_yuming
                install_ssltls
                install_onlyoffice_kodbox
                restart_ldnmp
                onlyoffice_kodbox_display
                docker_port=8001
                reverse_proxy
                nginx_status
                ;;
            5)
                clear
                add_yuming
                install_ssltls
                add_db "$yuming" "/home/docker/docker-compose.yml"
                dujiaoka_config
                restart_ldnmp				
                dujiaoka_display
                nginx_status
                ;;  
            6)
                clear
                add_yuming
                install_ssltls
                add_db "$yuming" "/home/docker/docker-compose.yml"
                cms_config
                restart_ldnmp				
                cms_display
                nginx_status
                ;;  
            7)
                clear
                add_yuming
                install_ssltls
                add_db "$yuming" "/home/docker/docker-compose.yml"
                flarum_config
                restart_ldnmp				
                flarum_display
                nginx_status
                ;;
            21)
                clear
                add_yuming
				install_ssltls
                cd /home/docker/html
                mkdir -p /home/docker/html/$yuming
                install_epusdt "/home/docker/html/$yuming" "/home/docker/docker-compose.yml"
                ;;
            22)
                clear
                add_yuming
                install_ssltls
                cd /home/docker/html
                mkdir -p /home/docker/html/$yuming
                get_dbusepasswd "/home/docker/docker-compose.yml"
                install_lobe "/home/docker/docker-compose.yml"
                ;;
            23)
                clear
                add_yuming
                install_ssltls
                cd /home/docker/html
                mkdir -p /home/docker/html/$yuming
                install_geminiPro "/home/docker/docker-compose.yml"
                ;;
            24)
                clear
                add_yuming
                install_ssltls
                cd /home/docker/html
                mkdir -p /home/docker/html/$yuming
                install_vaultwarden "/home/docker/html/$yuming" "/home/docker/docker-compose.yml"
                ;;
            25)
                clear
                add_yuming
                install_ssltls
                cd /home/docker/html
                mkdir -p /home/docker/html/$yuming
                install_onlyoffice "/home/docker/html/$yuming" "/home/docker/docker-compose.yml"
                ;;
            26)
                clear
                add_yuming
                install_ssltls
                cd /home/docker/html
                mkdir -p /home/docker/html/$yuming
                install_nextcloud "/home/docker/html/$yuming" "/home/docker/docker-compose.yml"
                ;;
            27)
                clear
                add_yuming
                install_ssltls
                cd /home/docker/html
                mkdir -p /home/docker/html/$yuming
                install_speedtest "/home/docker/docker-compose.yml"
                ;;
            28)
                clear
                add_yuming
                install_ssltls
                cd /home/docker/html
                mkdir -p /home/docker/html/$yuming
                install_portainer "/home/docker/html/$yuming" "/home/docker/docker-compose.yml"
                ;;
            29)
                install_Poste
                ;;
            30)
                clear
                add_yuming
                install_ssltls
                cd /home/docker/html
                mkdir -p /home/docker/html/$yuming
                install_halo "/home/docker/html/$yuming" "/home/docker/docker-compose.yml"
                ;; 
            31)
                clear
                add_yuming
                install_ssltls
                cd /home/docker/html
                mkdir -p /home/docker/html/$yuming
                install_qbittorrent "/home/docker/html/$yuming" "/home/docker/docker-compose.yml"
                ;;  
            32)
                clear
                add_yuming
                install_ssltls
                cd /home/docker/html
                mkdir -p /home/docker/html/$yuming
                install_vscode_web "/home/docker/html/$yuming" "/home/docker/docker-compose.yml"
                ;;
            33)
                clear
                add_yuming
                install_ssltls
                cd /home/docker/html
                mkdir -p /home/docker/html/$yuming
                install_UptimeKuma "/home/docker/html/$yuming" "/home/docker/docker-compose.yml"
                ;;
            34)
                clear
                add_yuming
                install_ssltls
                cd /home/docker/html
                mkdir -p /home/docker/html/$yuming                
                install_cloudreve "/home/docker/docker-compose.yml"
                ;;  
            35)
                clear
                add_yuming
                install_ssltls
                cd /home/docker/html
                mkdir -p /home/docker/html/$yuming 
                install_librespeed "/home/docker/html/$yuming" "/home/docker/docker-compose.yml"                              
                ;;
            36)
                clear
                add_yuming
                install_ssltls
                cd /home/docker/html
                mkdir -p /home/docker/html/$yuming
                install_searxng "/home/docker/html/$yuming" "/home/docker/docker-compose.yml"                
                ;;
            37)
                clear
                add_yuming
                install_ssltls
                cd /home/docker/html
                mkdir -p /home/docker/html/$yuming
                install_photoprism "/home/docker/html/$yuming" "/home/docker/docker-compose.yml"                
                ;; 
            38)
                clear
                add_yuming
                install_ssltls
                cd /home/docker/html
                mkdir -p /home/docker/html/$yuming
                install_s_pdf "/home/docker/html/$yuming" "/home/docker/docker-compose.yml"                
                ;;
            39)
                clear
                add_yuming
                install_ssltls
                cd /home/docker/html
                mkdir -p /home/docker/html/$yuming
                install_drawio "/home/docker/html/$yuming" "/home/docker/docker-compose.yml"                
                ;;                             
            61)
                check_port
                install_dependency
                install_docker
                install_certbot
                install_nginx
                nginx_display
                ;;  
            62)
                clear
                ip_address
                add_yuming
                read -p "请输入跳转域名: " reverseproxy
                install_ssltls
                redirect_config
                nginx_status
                ;;
            63)
                clear
                ip_address
                add_yuming
                read -p "请输入你的反代IP: " reverseproxy
                read -p "请输入你的反代端口: " port
                install_ssltls
                reverseproxy_config
                nginx_status
                ;;
            64)
                clear
                add_yuming
                install_ssltls
                custom_static
                nginx_status
                ;;
            71)
                site_manage
                ;;
            72)
                cd /home/docker && tar czvf web_$(date +"%Y%m%d%H%M%S").tar.gz web
                backup_site_data
                ;;
            73)
                scheduled_remote_backup
                ;;
            74)
                # 还原全站数据
                clear
                cd /home/docker && ls -t /home/*.tar.gz | head -1 | xargs -I {} tar -xzf {}
                check_port
                install_dependency
                install_docker
                install_certbot
                clear
                echo "正在配置LDNMP环境，请耐心稍等……"
                docker exec nginx chmod -R 777 /var/www/html
                docker restart nginx > /dev/null 2>&1
                install_php
                clear
                echo "LDNMP环境安装完毕"
                echo "------------------------"
                ldnmp_info
                ;;
            75)
                site_defense_program
                ;;
            76)
                optimize_ldnmp
                ;;
            77)
                clear
                docker rm -f nginx php php74 mysql redis
                docker rmi nginx php:fpm php:7.4.33-fpm mysql redis

                check_port
                install_dependency
                install_docker
                install_certbot
                clear
                echo "正在配置LDNMP环境，请耐心稍等……"
                docker exec nginx chmod -R 777 /var/www/html
                docker restart nginx > /dev/null 2>&1
                install_php
                clear
                echo "LDNMP环境安装完毕"
                echo "------------------------"
                ldnmp_info
                ;;
            78)
                clear
                read -p "强烈建议先备份全部网站数据，再卸载LDNMP环境。确定删除所有网站数据吗？(Y/N): " choice
                case "$choice" in
                [Yy])
                    docker rm -f nginx php php74 mysql redis
                    docker rmi nginx php:fpm php:7.4.33-fpm mysql redis
                    rm -rf /home/docker/web
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
                echo "无效的输入!"
        esac
        break_end
    done
}

# 定义一个函数
check_path_and_output() {
    local input_path="$1"
    local defined_path="/home/docker/docker-compose.yml"

    # 比较输入路径和预定义路径
    if [ "$input_path" == "$defined_path" ]; then
        # 如果路径匹配，执行相关操作
        reverse_proxy
        # 获取外部 IP 地址
        ip_address
        clear
        echo "$docker_name 已经安装完成"
        echo "------------------------"     
        echo "您可以使用以下地址访问:"
        echo "https://$yuming"
        $docker_use
        $docker_passwd1
    else
        ip_address
        clear
        echo "$docker_name 已经安装完成"
        echo "------------------------"    
        echo "您可以使用以下地址访问:"
        echo "http:$ipv4_address:$docker_port"
        $docker_use
        $docker_passwd
    fi
}

# 安装应用
docker_app() {
    if docker inspect "$docker_name" &>/dev/null; then
        clear
        echo "$docker_name 已安装，访问地址: "
        ip_address
        echo "http:$ipv4_address:$docker_port"
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
                docker rm -f "$docker_name"
                docker rmi -f "$docker_img"

                $docker_run
                check_path_and_output $mysql_redis_php_path                                       
                ;;
            2)
                clear
                docker rm -f "$docker_name"
                docker rmi -f "$docker_img"
                rm -rf "/home/docker/$docker_name"
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
        read -p "确定安装吗？(Y/N): " choice
        case "$choice" in
            [Yy])
                clear
                # 安装 Docker（请确保有 install_docker 函数）
                install_docker
                $docker_run
                check_path_and_output $mysql_redis_php_path
                ;;
            [Nn])
                # 用户选择不安装
                ;;
            *)
                # 无效输入
                ;;
        esac
    fi

}

# 安装nginx-proxy-manager管理工具
nginx-proxy-manager() {

    # 设置超时时间（秒）
    timeout=20
    read -t $timeout -p "项目名称（默认输入：npm）" project_name
    docker_name=${project_name:-npm}
    # 如果没有输入，打印换行符
    [ -z "$project_name" ] && echo ""    
    read -t $timeout -p "部端口（默认输入：81）" project_port
    docker_port=${project_port:-81}
    [ -z "$project_port" ] && echo ""   
    docker_img="jc21/nginx-proxy-manager:latest"
    docker_run="docker run -d \
                    --name=$docker_name \
                    -p 80:80 \
                    -p $docker_port:81 \
                    -p 443:443 \
                    -v /home/docker/$docker_name/data:/data \
                    -v /home/docker/$docker_name/letsencrypt:/etc/letsencrypt \
                    --restart=always \
                    $docker_img"
    docker_describe="如果您已经安装了其他面板工具或者LDNMP建站环境，建议先卸载，再安装npm！"
    docker_url="官网介绍: https://nginxproxymanager.com/"
    docker_use="echo \"初始用户名: admin@example.com\""
    docker_passwd="echo \"初始密码: changeme\""
    docker_app
}



# 获取mysql_redis_php的信息
mysql_redis_php_info() {

    # 获取mysql版本
    dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/docker/docker-compose-mysql_redis_php.yml | tr -d '[:space:]')
    mysql_version=$(docker exec mysql mysql -u root -p"$dbrootpasswd" -e "SELECT VERSION();" 2>/dev/null | tail -n 1)
    echo -n "mysql : v$mysql_version"

    # 获取php版本
    php_version=$(docker exec php php -v 2>/dev/null | grep -oP "PHP \K[0-9]+\.[0-9]+\.[0-9]+")
    echo -n "            php : v$php_version"

    # 获取redis版本
    redis_version=$(docker exec redis redis-server -v 2>&1 | grep -oP "v=+\K[0-9]+\.[0-9]+")
    echo "            redis : v$redis_version"

    echo "------------------------"
    echo ""
}

# 安装mysql-redis-php
install_mysql_redis_php() {
 
    install_dependency
    install_docker
    install_prm
    install_php
    clear
    echo "mysql_redis_php环境安装完毕"
    echo "------------------------"
    mysql_redis_php_info
}

# 获取dbusepasswd密码
get_dbusepasswd() {
    local path="$1"
    dbusepasswd=$(grep -oP 'MYSQL_PASSWORD:\s*\K.*' "$path" | tr -d '[:space:]')
}

# 安装LobeChat聊天网站
install_lobe() {

    mysql_redis_php_path="$1"
    # 设置超时时间（秒）
    timeout=20
    read -t $timeout -p "项目名称（默认输入：lobe_chat）" project_name
    docker_name=${project_name:-lobe_chat}
    # 如果没有输入，打印换行符
    [ -z "$project_name" ] && echo ""    
    read -t $timeout -p "外部端口（默认输入：3210）" project_port
    docker_port=${project_port:-3210}
    [ -z "$project_port" ] && echo ""   
    read -p "请输入你的OPENAI_API_KEY: " apikey
    docker_img="lobehub/lobe-chat"

    docker_run="docker run -d \
                    --name=$docker_name \
                    -p $docker_port:3210 \
                    -e OPENAI_API_KEY=$apikey \
                    -e ACCESS_CODE=$dbusepasswd \
                    -e HIDE_USER_API_KEY=1 \
                    -e BASE_URL=https://api.openai.com \
                    --restart=always \
                    $docker_img"
    docker_describe="LobeChat 现在支持 OpenAI 最新的 gpt-4-vision 模型，具备视觉识别能力，这是一种能够感知视觉内容的多模态智能。"
    docker_url="官网介绍: https://github.com/lobehub/lobe-chat"
    docker_use='echo -e "密码: '"$dbusepasswd"'"'
    docker_passwd=""
    docker_passwd1=""
    docker_app
}

# 安装GeminiPro聊天网站
install_geminiPro() {

    mysql_redis_php_path="$1"
    # 设置超时时间（秒）
    timeout=20
    read -t $timeout -p "项目名称（默认输入：geminiprochat）" project_name
    docker_name=${project_name:-geminiprochat}
    # 如果没有输入，打印换行符
    [ -z "$project_name" ] && echo "" 
    read -t $timeout -p "外部端口（默认输入：3020）" project_port
    docker_port=${project_port:-3020}
    [ -z "$project_port" ] && echo "" 
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
    mysql_redis_php_path="$2"
    # 设置超时时间（秒）
    timeout=20
    read -t $timeout -p "项目名称（默认输入：vaultwarden）" project_name
    docker_name=${project_name:-vaultwarden}
    # 如果没有输入，打印换行符
    [ -z "$project_name" ] && echo "" 
    read -t $timeout -p "外部端口（默认输入：8050）" project_port
    docker_port=${project_port:-8050}
    [ -z "$project_port" ] && echo ""
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

# 安装kodbox可道云网盘
install_kodbox() {

    kodbox_path="$1"
    mysql_redis_php_path="$2"
    # 设置超时时间（秒）
    timeout=20
    read -t $timeout -p "项目名称（默认输入：kodbox）" project_name
    docker_name=${project_name:-kodbox}
    # 如果没有输入，打印换行符
    [ -z "$project_name" ] && echo ""  
    read -t $timeout -p "外部端口（默认输入：8980）" project_port
    docker_port=${project_port:-8980}
    [ -z "$project_port" ] && echo ""
    docker_img="kodcloud/kodbox:latest"
    add_db "$docker_name" "$mysql_redis_php_path"
    set_network_name "$mysql_redis_php_path"
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
    mysql_redis_php_path="$2"
    # 设置超时时间（秒）
    timeout=20
    read -t $timeout -p "项目名称（默认输入：dujiaoka）" project_name
    docker_name=${project_name:-dujiaoka}
    # 如果没有输入，打印换行符
    [ -z "$project_name" ] && echo ""    
    read -t $timeout -p "外部端口（默认输入：8920）" project_port
    docker_port=${project_port:-8920}
    [ -z "$project_port" ] && echo ""
    docker_img="stilleshan/dujiaoka:latest"
    add_db "$docker_name" "$mysql_redis_php_path"
    mkdir -p "$dujiaoka_path/$docker_name" && cd "$dujiaoka_path/$docker_name" && mkdir storage uploads && chmod -R 777 storage uploads && touch env.conf && chmod -R 777 env.conf
    wget -O "$dujiaoka_path/$docker_name/env.conf" https://raw.githubusercontent.com/zxl2008gz/docker/main/dujiaoka/env.conf
    sed -i "s/mysqlbase/$docker_name/g" "$dujiaoka_path/$docker_name/env.conf"
    sed -i "s/mysqluse/$dbuse/g" "$dujiaoka_path/$docker_name/env.conf"
    sed -i "s/mysqlpasswd/$dbusepasswd/g" "$dujiaoka_path/$docker_name/env.conf"

    set_network_name "$mysql_redis_php_path"

    docker_run="docker run -d \
                    --name=$docker_name \
                    -p $docker_port:80 \
                    --network $network_name \
                    -e INSTALL=true \
                    -v $dujiaoka_path/$docker_name/env.conf:/dujiaoka/.env
                    -v $dujiaoka_path/$docker_name/uploads:/dujiaoka/public/uploads
                    -v $dujiaoka_path/$docker_name/storage:/dujiaoka/storage
                    --restart=always \
                    $docker_img"
    docker_describe="独角数发卡网是一个自动化售货网站源码，支持多种支付方式，包括支付宝、微信、QQ钱包等，并且可以通过USDT进行收款。它的特点是简单易用、高效稳定，能够帮助站长快速搭建自己的售货系统。"
    docker_url=""
    docker_use='echo -e "安装信息如下： \n数据库地址: mysql \n数据库用户名: '"$dbuse"'\n密码: '"$dbusepasswd"'\n数据库名: '"$docker_name"' "'
    docker_passwd='echo -e "redis主机: redis \nredis密码: 默认不填写 \nredis端口: 6379"'
    docker_app    
}

# 安装epusdt收款地址
install_epusdt() {

    epusdt_path="$1" # 删除了错误的引号
    mysql_redis_php_path="$2"
   # 设置超时时间（秒）
    timeout=20
    read -t $timeout -p "项目名称（默认输入：epusdt）" project_name
    docker_name=${project_name:-epusdt}
    # 如果没有输入，打印换行符
    [ -z "$project_name" ] && echo ""    
    read -t $timeout -p "外部端口（默认输入：8000）" project_port
    docker_port=${project_port:-8000}
    [ -z "$project_port" ] && echo ""
    docker_img="stilleshan/epusdt:latest"
    mkdir -p "$epusdt_path/$docker_name" && cd "$epusdt_path/$docker_name" && mkdir epusdt && chmod -R 777 epusdt && cd "$epusdt_path/$docker_name/epusdt"
    add_db "$docker_name" "$mysql_redis_php_path"
    wget -O "$epusdt_path/$docker_name/epusdt/epusdt.sql" https://raw.githubusercontent.com/zxl2008gz/docker/main/epusdt/epusdt.sql
	# 设定数据文件的路径，你需要根据实际情况修改此路径
	datafile="$epusdt_path/$docker_name/epusdt/epusdt.sql"
    # 导入数据
	docker exec -i mysql mysql -u "$dbuse" -p"$dbusepasswd" "$dbname" < "$datafile"	

    wget -O "$epusdt_path/$docker_name/epusdt/epusdt.conf" https://raw.githubusercontent.com/zxl2008gz/docker/main/epusdt/epusdt.conf
    sed -i "s|mysql_user=epusdt|mysql_user=$dbuse|g" "$epusdt_path/$docker_name/epusdt/epusdt.conf"	
    sed -i "s|changeyourpassword|$dbusepasswd|g" "$epusdt_path/$docker_name/epusdt/epusdt.conf"	
    read -p "请输入你的tg机器人token: " tg_bot_token
    sed -i "s/你的tg机器人token/$tg_bot_token/g" "$epusdt_path/$docker_name/epusdt/epusdt.conf"
    read -p "请输入你的tgid: " tg_id
    sed -i "s/你的tgid/$tg_id/g" "$epusdt_path/$docker_name/epusdt/epusdt.conf" 

    set_network_name "$mysql_redis_php_path"

    docker_run="docker run -d \
                    --name=$docker_name \
                    -p $docker_port:8000 \
                    --network $network_name \
                    -e mysql_host=mysql \
                    -e mysql_database=$docker_name \
                    -e mysql_user=$dbuse \
                    -e mysql_passwd=$dbusepasswd \
                    -v $epusdt_path/$docker_name/epusdt/epusdt.conf:/app/.env \
                    --restart=always \
                    $docker_img"
    docker_describe="EPUSDT（Ether Pay USD Token）是一种基于区块链技术的数字货币，主要目标是提供一种稳定且安全的支付方式。它通常被用作数字资产交易、跨境支付、在线购物等领域的支付工具。"
    docker_url=""
    docker_use='echo -e "安装信息如下： \n数据库地址: mysql \n数据库用户名: '"$dbuse"'\n密码: '"$dbusepasswd"'\n数据库名: '"$docker_name"' "'
    docker_passwd='echo -e "商户ID: '$dbusepasswd'\n商户密钥: https://你的域名/api/v1/order/create-transaction"'
    docker_passwd1='echo -e "商户ID: '$dbusepasswd'\n商户密钥: https://'$yuming'/api/v1/order/create-transaction"'
    docker_app    
}

# onlyoffice在线办公OFFICE-kodbox版本
install_onlyoffice_kodbox() {

    cd ~ & wget https://static.kodcloud.com/kod/source/onlyoffice/7.4.1/officeData.zip & wget https://static.kodcloud.com/kod/source/onlyoffice/7.4.1/kodoffice.tar
    
    curl https://doc.kodcloud.com/tools/office/linux/install.sh | sh

    sh ~/run_office.sh

    rm -f ~/kodoffice.tar ~/officeData.zip

}

# onlyoffice_kodbox 显示
onlyoffice_kodbox_display() {
    clear
    echo "您的onlyoffice可道云版本搭建好了！"
    echo "https://$yuming"
}

# onlyoffice_kodbox 显示
onlyoffice_kod_display() {
    clear
    echo "您的onlyoffice可道云版本搭建好了！"
    ip_address
    echo "http:$ipv4_address:8001"
}


# onlyoffice在线办公OFFICE
install_onlyoffice() {

    onlyoffice_path="$1"
    mysql_redis_php_path="$2"   
    # 设置超时时间（秒）
    timeout=20
    read -t $timeout -p "项目名称（默认输入：onlyoffice）" project_name
    docker_name=${project_name:-onlyoffice}
    # 如果没有输入，打印换行符
    [ -z "$project_name" ] && echo "" 
    read -t $timeout -p "外部端口（默认输入：8082）" project_port
    docker_port=${project_port:-8082}
    [ -z "$project_port" ] && echo ""
    docker_img="onlyoffice/documentserver"
    set_network_name "$mysql_redis_php_path"
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
    mysql_redis_php_path="$2"
    # 设置超时时间（秒）
    timeout=20
    read -t $timeout -p "项目名称（默认输入：nextcloud）" project_name
    docker_name=${project_name:-nextcloud}
    # 如果没有输入，打印换行符
    [ -z "$project_name" ] && echo "" 
    read -t $timeout -p "外部端口（默认输入：8989）" project_port
    docker_port=${project_port:-8989}
    [ -z "$project_port" ] && echo ""
    docker_img="nextcloud:latest"
    add_db "$docker_name" "$mysql_redis_php_path"
    set_network_name "$mysql_redis_php_path"
    mkdir -p "$nextcloud_path/$docker_name"
    wget -O "$nextcloud_path/$docker_name/Dockerfile" https://raw.githubusercontent.com/zxl2008gz/docker/main/nextcloud/Dockerfile
    docker build -t nextcloud-with-bz2 "$nextcloud_path/$docker_name"
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

    mysql_redis_php_path="$1"   
    # 设置超时时间（秒）
    timeout=20
    read -t $timeout -p "项目名称（默认输入：looking-glass）" project_name
    docker_name=${project_name:-looking-glass}
    # 如果没有输入，打印换行符
    [ -z "$project_name" ] && echo "" 
    read -t $timeout -p "外部端口（默认输入：89）" project_port
    docker_port=${project_port:-89}
    [ -z "$project_port" ] && echo ""
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
    # 设置超时时间（秒）
    timeout=20 
    read -t $timeout -p "项目名称（默认输入：portainer）" project_name
    docker_name=${project_name:-portainer}
    # 如果没有输入，打印换行符
    [ -z "$project_name" ] && echo "" 
    read -t $timeout -p "外部端口（默认输入：9050）" project_port
    docker_port=${project_port:-9050}
    [ -z "$project_port" ] && echo ""
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
install_Post--;/e() {
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
    read -p "确定安装poste.io吗？(Y/N): " choice
    case "$choice" in
        [Yy])
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
            ;;
        [Nn])
            ;;
        *)
            ;;
    esac
fi
}

# 安装halo网站
install_halo() {

    halo_path="$1"
    mysql_redis_php_path="$2"
    # 设置超时时间（秒）
    timeout=20 
    read -t $timeout -p "项目名称（默认输入：halo）" project_name
    docker_name=${project_name:-halo}
    # 如果没有输入，打印换行符
    [ -z "$project_name" ] && echo "" 
    read -t $timeout -p "外部端口（默认输入：8010）" project_port
    docker_port=${project_port:-8010}
    [ -z "$project_port" ] && echo ""
    set_network_name "$mysql_redis_php_path"
    docker_img="halohub/halo:2.11"
    docker_run="docker run -d \
                    --name=$docker_name \
                    --restart=always \
                    --network $network_name \
                    -p $docker_port:8090 \
                    -v $halo_path/$docker_name/.halo2:/root/.halo2 \
                    $docker_img"
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
    mysql_redis_php_path="$2"
    # 设置超时时间（秒）
    timeout=20 
    read -t $timeout -p "项目名称（默认输入：qbittorrent）" project_name
    docker_name=${project_name:-qbittorrent}
    # 如果没有输入，打印换行符
    [ -z "$project_name" ] && echo "" 
    read -t $timeout -p "外部端口（默认输入：8081）" project_port
    docker_port=${project_port:-8081}
    [ -z "$project_port" ] && echo ""
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
                    -v $halo_path/$docker_name/config:/config \
                    -v $halo_path/$docker_name/downloads:/downloads \
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
    mysql_redis_php_path="$2"
    # 设置超时时间（秒）
    timeout=20 
    read -t $timeout -p "项目名称（默认输入：vscode_web）" project_name
    docker_name=${project_name:-vscode_web}
    # 如果没有输入，打印换行符
    [ -z "$project_name" ] && echo "" 
    read -t $timeout -p "外部端口（默认输入：8180）" project_port
    docker_port=${project_port:-8180}
    [ -z "$project_port" ] && echo ""
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
    mysql_redis_php_path="$2"
    # 设置超时时间（秒）
    timeout=20 
    read -t $timeout -p "项目名称（默认输入：uptimeKuma）" project_name
    docker_name=${project_name:-uptimeKuma}
    # 如果没有输入，打印换行符
    [ -z "$project_name" ] && echo "" 
    read -t $timeout -p "外部端口（默认输入：3003）" project_port
    docker_port=${project_port:-3003}
    [ -z "$project_port" ] && echo ""
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

# librespeed测速工具
install_librespeed() {

    librespeed_path="$1"
    mysql_redis_php_path="$2"
    # 设置超时时间（秒）
    timeout=20 
    read -t $timeout -p "项目名称（默认输入：librespeed）" project_name
    docker_name=${project_name:-librespeed}
    # 如果没有输入，打印换行符
    [ -z "$project_name" ] && echo "" 
    read -t $timeout -p "外部端口（默认输入：6681）" project_port
    docker_port=${project_port:-6681}
    [ -z "$project_port" ] && echo ""
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
    mysql_redis_php_path="$2"
    # 设置超时时间（秒）
    timeout=20 
    read -t $timeout -p "项目名称（默认输入：searxng）" project_name
    docker_name=${project_name:-searxng}
    # 如果没有输入，打印换行符
    [ -z "$project_name" ] && echo "" 
    read -t $timeout -p "外部端口（默认输入：8700）" project_port
    docker_port=${project_port:-8700}
    [ -z "$project_port" ] && echo ""
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
    mysql_redis_php_path="$2"
    # 设置超时时间（秒）
    timeout=20 
    read -t $timeout -p "项目名称（默认输入：photoprism）" project_name
    docker_name=${project_name:-photoprism}
    # 如果没有输入，打印换行符
    [ -z "$project_name" ] && echo "" 
    read -t $timeout -p "外部端口（默认输入：2342）" project_port
    docker_port=${project_port:-2342}
    [ -z "$project_port" ] && echo ""
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
                    -v $searxng_path/$docker_name/storage:/photoprism/storage \
                    -v $searxng_path/$docker_name/Pictures:/photoprism/originals \
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
    mysql_redis_php_path="$2"
    # 设置超时时间（秒）
    timeout=20 
    read -t $timeout -p "项目名称（默认输入：s_pdf）" project_name
    docker_name=${project_name:-s_pdf}
    # 如果没有输入，打印换行符
    [ -z "$project_name" ] && echo "" 
    read -t $timeout -p "外部端口（默认输入：8020）" project_port
    docker_port=${project_port:-8020}
    [ -z "$project_port" ] && echo ""
    docker_img="frooodle/s-pdf:latest"
    docker_run="docker run -d \
                    --name=$docker_name \
                    --restart=always \
                    -p $docker_port:8080 \
                    -v $searxng_path/$docker_name/trainingData:/usr/share/tesseract-ocr/5/tessdata \
                    -v $searxng_path/$docker_name/extraConfigs:/configs \
                    -v $searxng_path/$docker_name/logs:/logs \
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
    mysql_redis_php_path="$2"
    # 设置超时时间（秒）
    timeout=20 
    read -t $timeout -p "项目名称（默认输入：drawio）" project_name
    docker_name=${project_name:-drawio}
    # 如果没有输入，打印换行符
    [ -z "$project_name" ] && echo "" 
    read -t $timeout -p "外部端口（默认输入：7080）" project_port
    docker_port=${project_port:-7080}
    [ -z "$project_port" ] && echo ""
    docker_img="jgraph/drawio"
    docker_run="docker run -d \
                    --name=$docker_name \
                    --restart=always \
                    -p $docker_port:8080 \
                    -v $searxng_path/$docker_name:/var/lib/drawio
                    $docker_img"
    docker_describe="这是一个强大图表绘制软件。思维导图，拓扑图，流程图，都能画"
    docker_url="官网介绍: https://www.drawio.com/"
    docker_use=""
    docker_passwd=""
    docker_passwd1=""
    docker_app
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
        echo "7. 安装onlyoffice可道云                8. 安装dujiaoka独角数发卡网  "
        echo "9. 安装epusdt收款地址                  10. onlyoffice在线办公OFFICE "
        echo "11. Nextcloud网盘                     12. Speedtest测速服务面板 "
        echo "13. portainer容器管理面板              14. Poste.io邮件服务器程序 "  
        echo "15. 安装Halo博客网站                   16. QB离线BT磁力下载面板"    
        echo "17. VScode网页版                      18. UptimeKuma监控工具" 
        echo "19. Cloudreve网盘                     20. LibreSpeed测速工具" 
        echo "21. searxng聚合搜索站                 22. PhotoPrism私有相册系统"
        echo "23. StirlingPDF工具大全               24. drawio免费的在线图表软件"               
        echo "------------------------"
        echo "0. 返回主菜单"
        echo "------------------------"
        read -p "请输入你的选择: " sub_choice

        case $sub_choice in
            1)
                nginx-proxy-manager
                ;;
            2)
                install_mysql_redis_php
                ;;
            3)  
                get_dbusepasswd "/home/docker/docker-compose-mysql_redis_php.yml"
                install_lobe "/home/docker/docker-compose-mysql_redis_php.yml"
                ;;
            4)
                install_geminiPro "/home/docker/docker-compose-mysql_redis_php.yml"
                ;;
            5)
                install_vaultwarden "/home/docker" "/home/docker/docker-compose-mysql_redis_php.yml"
                ;;
            6)
                install_kodbox "/home/docker" "/home/docker/docker-compose-mysql_redis_php.yml"
                ;;
            7)
                install_onlyoffice_kodbox
                onlyoffice_kod_display
                ;;
            8)
                install_dujiaoka "/home/docker" "/home/docker/docker-compose-mysql_redis_php.yml"
                ;;
            9)
                install_epusdt "/home/docker" "/home/docker/docker-compose-mysql_redis_php.yml"
                ;;
            10)
                install_onlyoffice "/home/docker" "/home/docker/docker-compose-mysql_redis_php.yml"
                ;;
            11)
                install_nextcloud "/home/docker" "/home/docker/docker-compose-mysql_redis_php.yml"
                ;;
            12) 
                install_speedtest "/home/docker/docker-compose-mysql_redis_php.yml"
                ;;
            13)
                install_portainer "/home/docker" "/home/docker/docker-compose-mysql_redis_php.yml"
                ;;
            14)
                install_Poste
                ;;
            15)
                install_halo "/home/docker" "/home/docker/docker-compose-mysql_redis_php.yml"
                ;; 
            16)
                install_qbittorrent "/home/docker" "/home/docker/docker-compose-mysql_redis_php.yml"
                ;;
            17)
                install_vscode_web "/home/docker" "/home/docker/docker-compose-mysql_redis_php.yml"
                ;;  
            18)
                install_UptimeKuma "/home/docker" "/home/docker/docker-compose-mysql_redis_php.yml"
                ;;   
            19)
                install_cloudreve "/home/docker/docker-compose-mysql_redis_php.yml"
                ;; 
            20)
                install_librespeed "/home/docker" "/home/docker/docker-compose-mysql_redis_php.yml"
                ;;
            21)
                install_searxng "/home/docker" "/home/docker/docker-compose-mysql_redis_php.yml"
                ;;
            22)
                install_photoprism "/home/docker" "/home/docker/docker-compose-mysql_redis_php.yml"
                ;;
            23)
                install_s_pdf "/home/docker" "/home/docker/docker-compose-mysql_redis_php.yml"
                ;;
            24)
                install_drawio "/home/docker" "/home/docker/docker-compose-mysql_redis_php.yml"
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

# 设置快捷键
set_shortcut_keys() {
    read -p "请输入你的快捷按键: " kuaijiejian
    echo "alias $kuaijiejian='~/solin.sh'" >> ~/.bashrc
    source ~/.bashrc
    echo "快捷键已设置"    
}

# 安装Python最新版
install_python() {
    RED="\033[31m"
    GREEN="\033[32m"
    YELLOW="\033[33m"
    NC="\033[0m"

    # 系统检测
    OS=$(grep -oP '(?<=^ID=).*' /etc/os-release | tr -d '"')

    if [[ $OS == "debian" || $OS == "ubuntu" || $OS == "centos" || $OS == "alpine" ]]; then
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
            if [[ $OS == "centos" ]]; then
                echo "正在卸载旧版本的Python3..."
                rm -rf /usr/local/python3* >/dev/null 2>&1
            elif [[ $OS == "alpine" ]]; then
                echo "正在卸载旧版本的Python3..."
                apk del python3
            else
                echo "正在卸载旧版本的Python3..."
                apt --purge remove python3 python3-pip -y
                rm -rf /usr/local/python3*
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
    if [[ $OS == "centos" ]]; then
        echo "正在为 CentOS 安装依赖..."
        yum update
        yum groupinstall -y "development tools"
        yum install wget openssl-devel bzip2-devel libffi-devel zlib-devel -y
    elif [[ $OS == "alpine" ]]; then
        echo "正在为 Alpine Linux 安装依赖..."
        apk update
        apk add --no-cache gcc musl-dev openssl-dev libffi-dev zlib-dev make readline-dev ncurses-dev sqlite-dev tk-dev gdbm-dev libc-dev bzip2-dev xz-dev
    else
        echo "正在为 Debian/Ubuntu 安装依赖..."
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
}

# 修改SSH端口
modify_ssh_port() {
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
}
 
# 优化DNS
set_dns() {
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
}

# DD系统2
dd_xitong_2() {
    echo "任意键继续，重装后初始用户名: root  初始密码: LeitboGi0ro  初始端口: 22"
    read -n 1 -s -r -p ""
    install wget
    wget --no-check-certificate -qO InstallNET.sh 'https://raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh' && chmod a+x InstallNET.sh
}

# DD系统3
dd_xitong_3() {
    echo "任意键继续，重装后初始用户名: Administrator  初始密码: Teddysun.com  初始端口: 3389"
    read -n 1 -s -r -p ""
    install wget
    wget --no-check-certificate -qO InstallNET.sh 'https://raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh' && chmod a+x InstallNET.sh
}

# DD系统
DD_xitong() {

    clear
    echo "请备份数据，将为你重装系统，预计花费15分钟。"
    echo -e "\e[37m感谢MollyLau和MoeClub的脚本支持！\e[0m "
    read -p "确定继续吗？(Y/N): " choice

    case "$choice" in
        [Yy])
            while true; do
                echo "------------------------"
                echo "1. Debian 12"
                echo "2. Debian 11"
                echo "3. Debian 10"
                echo "4. Debian 9"
                echo "------------------------"
                echo "11. Ubuntu 24.04"
                echo "12. Ubuntu 22.04"
                echo "13. Ubuntu 20.04"
                echo "14. Ubuntu 18.04"
                echo "------------------------"
                echo "21. CentOS 9"
                echo "22. CentOS 8"
                echo "23. CentOS 7"
                echo "------------------------"
                echo "31. Alpine 3.19"
                echo "------------------------"
                echo "41. Windows 11"
                echo "42. Windows 10"
                echo "43. Windows Server 2022"
                echo "44. Windows Server 2019"
                echo "44. Windows Server 2016"
                echo "------------------------"
                read -p "请选择要重装的系统: " sys_choice

                case "$sys_choice" in
                    1)
                        xitong="-d 12"
                        dd_xitong_1
                        exit
                        reboot
                        ;;
                    2)
                        xitong="-d 11"
                        dd_xitong_1
                        reboot
                        exit
                        ;;
                    3)
                        xitong="-d 10"
                        dd_xitong_1
                        reboot
                        exit
                        ;;
                    4)
                        xitong="-d 9"
                        dd_xitong_1
                        reboot
                        exit
                        ;;
                    11)
                        dd_xitong_2
                        bash InstallNET.sh -ubuntu 24.04
                        reboot
                        exit
                        ;;
                    12)
                        dd_xitong_2
                        bash InstallNET.sh -ubuntu 22.04
                        reboot
                        exit
                        ;;
                    13)
                        xitong="-u 20.04"
                        dd_xitong_1
                        reboot
                        exit
                        ;;
                    14)
                        xitong="-u 18.04"
                        dd_xitong_1
                        reboot
                        exit
                        ;;
                    21)
                        dd_xitong_2
                        bash InstallNET.sh -centos 9
                        reboot
                        exit
                        ;;
                    22)
                        dd_xitong_2
                        bash InstallNET.sh -centos 8
                        reboot
                        exit
                        ;;   
                    23)
                        dd_xitong_2
                        bash InstallNET.sh -centos 7
                        reboot
                        exit
                        ;;
                    31)
                        dd_xitong_2
                        bash InstallNET.sh -alpine
                        reboot
                        exit
                        ;;
                    41)
                        dd_xitong_3
                        bash InstallNET.sh -windows 11 -lang "cn"
                        reboot
                        exit
                        ;;
                    42)
                        dd_xitong_3
                        bash InstallNET.sh -windows 10 -lang "cn"
                        reboot
                        exit
                        ;;
                    43)
                        dd_xitong_3
                        bash InstallNET.sh -windows 2022 -lang "cn"
                        reboot
                        exit
                        ;;
                    44)
                        dd_xitong_3
                        bash InstallNET.sh -windows 2019 -lang "cn"
                        reboot
                        exit
                        ;;
                    45)
                        dd_xitong_3
                        bash InstallNET.sh -windows 2016 -lang "cn"
                        reboot
                        exit
                        ;;                    
                    *)
                        echo "无效的选择，请重新输入。"
                        ;;
                esac
            done
            ;;
        [Nn])
            echo "已取消"
            ;;
        *)
            echo "无效的选择，请输入 Y 或 N。"
            ;;
    esac
}

# 创建新用户
create_new_user() {
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
}

# 切换优先IPV4/IPV6
switch_ipv4_ipv6() {
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
}

# 修改虚拟内存大小
modify_swap() {

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
}

# 用户管理
user_management() {
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
}

# 密码生成器
password_generator() {
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
}

# 设置时区
set_time_zone() {
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
}

# 升级BBR3内核
update_bbr3() {
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
                    apt purge -y 'linux-*xanmod1*'
                    update-grub

                    wget -qO - https://raw.githubusercontent.com/zxl2008gz/sh/main/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg --yes

                    # 步骤3：添加存储库
                    echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | tee /etc/apt/sources.list.d/xanmod-release.list

                    version=$(wget -q https://raw.githubusercontent.com/zxl2008gz/sh/main/check_x86-64_psabi.sh && chmod +x check_x86-64_psabi.sh && ./check_x86-64_psabi.sh | grep -oP 'x86-64-v\K\d+|x86-64-v\d+')

                    apt update -y
                    apt install -y linux-xanmod-x64v$version

                    echo "XanMod内核已更新。重启后生效"
                    rm -f /etc/apt/sources.list.d/xanmod-release.list
                    rm -f check_x86-64_psabi.sh*

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

        # wget -qO - https://dl.xanmod.org/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg --yes
        wget -qO - https://raw.githubusercontent.com/zxl2008gz/sh/main/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg --yes

        # 步骤3：添加存储库
        echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | tee /etc/apt/sources.list.d/xanmod-release.list

        # version=$(wget -q https://dl.xanmod.org/check_x86-64_psabi.sh && chmod +x check_x86-64_psabi.sh && ./check_x86-64_psabi.sh | grep -oP 'x86-64-v\K\d+|x86-64-v\d+')
        version=$(wget -q https://raw.githubusercontent.com/zxl2008gz/sh/main/check_x86-64_psabi.sh && chmod +x check_x86-64_psabi.sh && ./check_x86-64_psabi.sh | grep -oP 'x86-64-v\K\d+|x86-64-v\d+')

        apt update -y
        apt install -y linux-xanmod-x64v$version

        # 步骤5：启用BBR3
        cat > /etc/sysctl.conf << EOF
net.core.default_qdisc=fq_pie
net.ipv4.tcp_congestion_control=bbr
EOF
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
}

# 防火墙设置
ufw_manage() {
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

                    cat > /etc/iptables/rules.v4 << EOF
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A FORWARD -i lo -j ACCEPT
-A INPUT -p tcp --dport $current_port -j ACCEPT
COMMIT
EOF
                    iptables-restore < /etc/iptables/rules.v4
                    ;;
                4)
                    current_port=$(grep -E '^ *Port [0-9]+' /etc/ssh/sshd_config | awk '{print $2}')

                    cat > /etc/iptables/rules.v4 << EOF
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A FORWARD -i lo -j ACCEPT
-A INPUT -p tcp --dport $current_port -j ACCEPT
COMMIT
EOF
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

            cat > /etc/iptables/rules.v4 << EOF
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A FORWARD -i lo -j ACCEPT
-A INPUT -p tcp --dport $current_port -j ACCEPT
COMMIT
EOF

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
}

# 修改主机名
modify_hostname() {
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
}

# 获取当前的源
get_current_source() {
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
}

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

# 更新源
update_source() {
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
}

# 定时任务
scheduled_tasks() {
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
}

# 多后台任务
tmux_run() {
    # Check if the session already exists
    tmux has-session -t $SESSION_NAME 2>/dev/null
    # $? is a special variable that holds the exit status of the last executed command
    if [ $? != 0 ]; then
      # Session doesn't exist, create a new one
      tmux new -s $SESSION_NAME
    else
      # Session exists, attach to it
      tmux attach-session -t $SESSION_NAME
    fi
}

# 工作区域
work_area() {
    while true; do
        clear
        echo "▶ 我的工作区"
        echo "系统将为你提供10个后台运行的工作区，你可以用来执行长时间的任务"
        echo "即使你断开SSH，工作区中的任务也不会中断，非常方便！来试试吧！"
        echo -e "\033[33m注意: 进入工作区后使用Ctrl+b再单独按d，退出工作区！\033[0m"
        echo "------------------------"
        echo "a. 安装工作区环境"
        echo "------------------------"
        echo "1. 1号工作区"
        echo "2. 2号工作区"
        echo "3. 3号工作区"
        echo "4. 4号工作区"
        echo "5. 5号工作区"
        echo "6. 6号工作区"
        echo "7. 7号工作区"
        echo "8. 8号工作区"
        echo "9. 9号工作区"
        echo "10. 10号工作区"
        echo "------------------------"
        echo "99. 工作区状态"
        echo "------------------------"
        echo "b. 卸载工作区"
        echo "------------------------"
        echo "0. 返回主菜单"
        echo "------------------------"
        read -p "请输入你的选择: " sub_choice

        case $sub_choice in
            a)
                clear
                install tmux
                ;;
            b)
                clear
                remove tmux
                ;;
            1)
                clear
                SESSION_NAME="work1"
                tmux_run

                ;;
            2)
                clear
                SESSION_NAME="work2"
                tmux_run
                ;;
            3)
                clear
                SESSION_NAME="work3"
                tmux_run
                ;;
            4)
                clear
                SESSION_NAME="work4"
                tmux_run
                ;;
            5)
                clear
                SESSION_NAME="work5"
                tmux_run
                ;;
            6)
                clear
                SESSION_NAME="work6"
                tmux_run
                ;;
            7)
                clear
                SESSION_NAME="work7"
                tmux_run
                ;;
            8)
                clear
                SESSION_NAME="work8"
                tmux_run
                ;;
            9)
                clear
                SESSION_NAME="work9"
                tmux_run
                ;;
            10)
                clear
                SESSION_NAME="work10"
                tmux_run
                ;;

            99)
                clear
                tmux list-sessions
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
}

# 系统工具
system_tool() {
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
                set_shortcut_keys          
                ;;
            2)
                clear
                echo "设置你的ROOT密码"
                passwd
                ;;
            3)
                clear
                set_rootpasswd
                ;;
            4)
                clear
                install_python
                ;;
            5)
                clear
                iptables_open
                remove iptables-persistent ufw firewalld iptables-services > /dev/null 2>&1
                echo "端口已全部开放"
                ;;
            6)
                clear
                modify_ssh_port
                ;;
            7)
                clear
                set_dns
                ;;
            8)
                DD_xitong
                ;;  
            9)
                clear
                create_new_user
                ;;  
            10)
                clear
                switch_ipv4_ipv6
                ;;   
            11)
                clear
                ss -tulnape
                ;;
            12)
                modify_swap
                ;;
            13)
                user_management
                ;;
            14)
                clear
                password_generator
                ;;
            15)
                set_time_zone
                ;;
            16)
                update_bbr3
                ;;
            17)
                ufw_manage
                ;;
            18)
                clear
                modify_hostname
                ;;
            19)
                get_current_source
                update_source
                ;;
            20)
                scheduled_tasks
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
        esac
        break_end
    done
}

# 主循环，用于显示菜单并处理用户输入
while true; do
    clear  # 清除屏幕
    # 显示菜单
    echo -e "\033[96m _   _ "
    echo "|_  | |  |    | |\ | "
    echo " _| |_|  |___ | | \| "
    echo "                                "
    echo -e "\033[96m solin一键脚本工具 v1.0.0 （支持Ubuntu/Debian/CentOS/Alpine系统）\033[0m"
    echo -e "\033[96m-输入\033[93ms\033[96m可快速启动此脚本-\033[0m"
    echo "------------------------"
    echo "1. 系统信息查询"
    echo "2. 系统更新"
    echo "3. 系统清理"
    echo "4. 常用工具"
    echo "5. BBR管理 ▶"
    echo "6. Docker管理器 ▶ "   
    echo "7. 测试脚本合集 ▶ "  
    echo "8. 甲骨文云脚本合集 ▶ "
    echo "9. 谷歌云脚本合集 ▶ "
    echo -e "\033[33m10. LDNMP建站-Nginx ▶ \033[0m"
    echo -e "\033[33m11. LDNMP建站-NginxProxyManager ▶ \033[0m"	
    echo "12. 我的工作区 ▶ "
    echo "13. 系统工具 ▶ "    
    echo "-----------------------"
    echo "00. 脚本更新"
    echo "------------------------"
    echo "0. 退出脚本"
    echo "------------------------"
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
            clear
            common_tool
            ;;        
        5)
            clear
            bbr_script
            ;;
        6)
            clear
            docker_manage 
            ;;
        7)
            clear
            test_script
            ;;
        8)
            clear
            oracle_script 
            ;;
        9)
            gcp_script
            ;;
        10)
            clear
            install_ldnmp 
            ;;
        11)
            panel_tools
            ;;
        12)
            clear
            work_area
            ;; 
        13)            
            clear
            system_tool
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
