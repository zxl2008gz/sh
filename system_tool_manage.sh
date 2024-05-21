#!/bin/bash

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

# 函数：退出
break_end() {
	echo -e "\033[0;32m操作完成\033[0m"
	echo "按任意键继续..."
	read -n 1 -s -r -p ""
	echo
	clear
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

# 设置快捷键
set_shortcut_keys() {
    read -p "请输入你的快捷按键: " kuaijiejian
    # 添加完整的命令路径以避免任何混淆
    echo "alias $kuaijiejian='~/solin.sh'" >> ~/.bashrc
    # 提示用户手动source或重启终端
    source ~/.bashrc
    echo "快捷键已设置。"
}

# 设置root密码
set_rootpasswd() {

    echo "设置你的ROOT密码"
    passwd
    if [ $? -ne 0 ]; then
        echo "密码设置失败，请重试。"
        return 1
    fi
    # 修改 SSH 配置以允许 root 登录
    echo "正在修改 SSH 配置以允许 ROOT 登录..."
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
    service sshd restart
    if [ $? -ne 0 ]; then
        echo "SSH 服务重启失败，请手动重启服务。"
        return 1
    fi

    echo "ROOT登录设置完毕！"
    while true; do
        if ask_confirmation "需要重启服务器吗？"; then
            echo "正在重启服务器..."
            reboot
        else
            echo "安装已取消。"
        fi
    done
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

# DD系统1
dd_xitong_1() {    
    read -p "请输入你重装后的密码: " vpspasswd
    echo "任意键继续，重装后初始用户名: root  初始密码: $vpspasswd  初始端口: 22"
    read -n 1 -s -r -p ""
    install wget
    bash <(wget --no-check-certificate -qO- 'https://raw.githubusercontent.com/MoeClub/Note/master/InstallNET.sh') $xitong -v 64 -p $vpspasswd -port 22
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

            add_swap "$new_swap"
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
        break_end
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
                break_end          
                ;;
            2)
                clear
                echo "设置你的ROOT密码"
                passwd
                break_end
                ;;
            3)
                clear
                set_rootpasswd
                break_end
                ;;
            4)
                clear
                install_python
                break_end
                ;;
            5)
                clear
                iptables_open
                remove iptables-persistent ufw firewalld iptables-services > /dev/null 2>&1
                echo "端口已全部开放"
                break_end
                ;;
            6)
                clear
                modify_ssh_port
                break_end
                ;;
            7)
                clear
                set_dns
                break_end
                ;;
            8)
                DD_xitong
                break_end
                ;;  
            9)
                clear
                create_new_user
                break_end
                ;;  
            10)
                clear
                switch_ipv4_ipv6
                break_end
                ;;   
            11)
                clear
                ss -tulnape
                break_end
                ;;
            12)
                modify_swap
                break_end
                ;;
            13)
                user_management
                break_end
                ;;
            14)
                clear
                password_generator
                break_end
                ;;
            15)
                set_time_zone
                ;;
            16)
                update_bbr3
                break_end
                ;;
            17)
                ufw_manage
                break_end
                ;;
            18)
                clear
                modify_hostname
                break_end
                ;;
            19)
                get_current_source
                update_source
                break_end
                ;;
            20)
                scheduled_tasks
                break_end
                ;;
            99)
                clear
                echo "正在重启服务器，即将断开SSH连接"
                reboot
              ;;
            0)
                break
                ;;
            *)
                echo "无效的输入!"
        esac
    done
}

system_tool
