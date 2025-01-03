#!/bin/bash

huang='\033[33m'
bai='\033[0m'
lv='\033[0;32m'
lan='\033[0;34m'
hong='\033[31m'
lianglan='\033[96m'
hui='\e[37m'

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
        echo -e "${huang}注意: 进入工作区后使用Ctrl+b再单独按d，退出工作区！${bai}"
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
                break
                ;;
            *)
                echo "无效的输入!"
                ;;
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

#设置快捷键
set_shortcut_keys() {
    clear
    echo "设置脚本启动快捷键"
    echo "------------------------"

    # 检查 solin.sh 是否存在
    if [ ! -f ~/solin.sh ]; then
        echo "错误: ~/solin.sh 文件不存在"
        return 1
    fi

    # 检查 .bashrc 文件是否存在
    if [ ! -f ~/.bashrc ]; then
        touch ~/.bashrc
    fi

    # 检查是否已经设置了别名
    if grep -q "alias.*='.*solin.sh'" ~/.bashrc; then
        # 获取所有现有的别名
        echo "当前已设置的快捷键:"
        grep "alias.*='.*solin.sh'" ~/.bashrc | while read -r line; do
            current_alias=$(echo "$line" | awk -F"=" '{print $1}' | awk '{print $2}')
            echo "$current_alias"
        done
    else
        echo "当前未设置快捷键"
    fi

    # 获取用户输入的新别名
    read -p "请输入新的快捷键名称: " new_alias

    if [ -n "$new_alias" ]; then
        # 删除所有指向 solin.sh 的别名
        sed -i "/alias.*='.*solin.sh'/d" ~/.bashrc

        # 添加新的别名
        echo "alias $new_alias='bash ~/solin.sh'" >> ~/.bashrc
        
        echo "快捷键已设置为: $new_alias"
        echo "------------------------"
        echo "请执行以下命令使快捷键生效："
        echo "source ~/.bashrc"

        # 提示用户执行source命令
        read -p "是否立即执行source命令？(y/n): " execute_source
        if [[ $execute_source == "y" || $execute_source == "Y" ]]; then
            exec bash
        fi
    else
        echo "快捷键名称不能为空！"
    fi
}

solin() {
    kjjian
    exit
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

root_use() {
    clear
    [ "$EUID" -ne 0 ] && echo -e "${huang}请注意，该功能需要root用户才能运行！${bai}" && break_end && solin
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

#重启 SSH 服务
restart_ssh() {

    if command -v dnf &>/dev/null; then
        systemctl restart sshd
    elif command -v yum &>/dev/null; then
        systemctl restart sshd
    elif command -v apt &>/dev/null; then
        service ssh restart
    elif command -v apk &>/dev/null; then
        service sshd restart
    else
        echo "未知的包管理器!"
        return 1
    fi

}

# 修改SSH端口
modify_ssh_port() {
    # 验证端口号
    validate_port() {
        local port=$1
        if [[ ! "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
            return 1
        fi
        return 0
    }

    # 备份SSH配置
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d_%H%M%S)

    # 去掉Port的注释
    sed -i 's/#Port/Port/' /etc/ssh/sshd_config

    # 读取当前SSH端口
    current_port=$(grep -E '^ *Port [0-9]+' /etc/ssh/sshd_config | awk '{print $2}')
    echo "当前的SSH端口号是: $current_port"
    echo "------------------------"

    while true; do
        read -p "请输入新的SSH端口号 (1-65535): " new_port
        if validate_port "$new_port"; then
            break
        else
            echo "错误：无效的端口号，请输入1-65535之间的数字"
        fi
    done

    # 修改端口
    sed -i "s/Port [0-9]\+/Port $new_port/g" /etc/ssh/sshd_config

    # 测试配置
    if ! sshd -t; then
        echo "错误：SSH配置测试失败，正在还原配置..."
        cp /etc/ssh/sshd_config.bak.$(date +%Y%m%d_%H%M%S) /etc/ssh/sshd_config
        return 1
    fi

    # 重启SSH服务
    if ! restart_ssh; then
        echo "错误：重启SSH服务失败，正在还原配置..."
        cp /etc/ssh/sshd_config.bak.$(date +%Y%m%d_%H%M%S) /etc/ssh/sshd_config
        restart_ssh
        return 1
    fi

    echo "SSH端口已修改为: $new_port"
    echo "配置已备份至: /etc/ssh/sshd_config.bak.$(date +%Y%m%d_%H%M%S)"

    # 开放新端口
    clear
    iptables_open
    remove iptables-persistent ufw firewalld iptables-services > /dev/null 2>&1
}

#DNS配置
dns_config(){
    # 验证DNS地址格式
    validate_ip() {
        local ip=$1
        if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            return 0
        elif [[ $ip =~ ^[0-9a-fA-F:]+$ ]]; then
            return 0
        else
            return 1
        fi
    }

    # 检查机器是否有IPv6地址
    ipv6_available=0
    if [[ $(ip -6 addr | grep -c "inet6") -gt 0 ]]; then
        ipv6_available=1
    fi

    # 验证DNS地址
    for dns in "$dns1_ipv4" "$dns2_ipv4"; do
        if ! validate_ip "$dns"; then
            echo "错误: 无效的IPv4 DNS地址: $dns"
            return 1
        fi
    done

    if [[ $ipv6_available -eq 1 ]]; then
        for dns in "$dns1_ipv6" "$dns2_ipv6"; do
            if ! validate_ip "$dns"; then
                echo "错误: 无效的IPv6 DNS地址: $dns"
                return 1
            fi
        done
    fi

    # 备份当前DNS配置
    cp /etc/resolv.conf /etc/resolv.conf.bak

    # 写入新的DNS配置
    {
        echo "nameserver $dns1_ipv4"
        echo "nameserver $dns2_ipv4"
        if [[ $ipv6_available -eq 1 ]]; then
            echo "nameserver $dns1_ipv6"
            echo "nameserver $dns2_ipv6"
        fi
    } > /etc/resolv.conf

    echo "DNS地址已更新"
    echo "------------------------"
    cat /etc/resolv.conf
    echo "------------------------"
    echo "原DNS配置已备份至 /etc/resolv.conf.bak"
}

# 优化DNS
set_dns() {
    echo "当前DNS地址"
    echo "------------------------"
    cat /etc/resolv.conf
    echo "------------------------"
    echo ""
    # 询问用户是否要优化DNS设置
    read -p "是否要设置DNS地址？(y/n): " choice

    if [ "$choice" == "y" ]; then
        # 定义DNS地址
        read -p "1. 国外DNS优化    2. 国内DNS优化    0. 退出  : " Limiting

        case "$Limiting" in
            1)
                dns1_ipv4="1.1.1.1"
                dns2_ipv4="8.8.8.8"
                dns1_ipv6="2606:4700:4700::1111"
                dns2_ipv6="2001:4860:4860::8888"
                dns_config
                ;;

            2)
                dns1_ipv4="223.5.5.5"
                dns2_ipv4="183.60.83.19"
                dns1_ipv6="2400:3200::1"
                dns2_ipv6="2400:da00::6666"
                dns_config
                ;;
            0)
                echo "已取消"
                ;;
            *)
                echo "无效的选择，请输入 Y 或 N。"
                ;;
        esac    
    else
        echo "DNS设置未更改"
    fi
}

# DD系统1
dd_xitong_1() {
    echo -e "重装后初始用户名: ${huang}root${bai}  初始密码: ${huang}LeitboGi0ro${bai}  初始端口: ${huang}22${bai}"
    read -n 1 -s -r -p ""
    install wget
    wget --no-check-certificate -qO InstallNET.sh 'https://raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh' && chmod a+x InstallNET.sh
}

# DD系统2
dd_xitong_2() {
    echo -e "重装后初始用户名: ${huang}Administrator${bai}  初始密码: ${huang}Teddysun.com${bai}  初始端口: ${huang}3389${bai}"
    read -n 1 -s -r -p ""
    install wget
    wget --no-check-certificate -qO InstallNET.sh 'https://raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh' && chmod a+x InstallNET.sh
}

# DD系统3
dd_xitong_3() {
    echo -e "重装后初始用户名: ${huang}root${bai}  初始密码: ${huang}123@@@${bai}  初始端口: ${huang}22${bai}"
    echo -e "按任意键继续..."
    read -n 1 -s -r -p ""
    curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh
}

# DD系统4
dd_xitong_4() {
    echo -e "重装后初始用户名: ${huang}Administrator${bai}  初始密码: ${huang}123@@@${bai}  初始端口: ${huang}3389${bai}"
    echo -e "按任意键继续..."
    read -n 1 -s -r -p ""
    curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh
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
                echo "31. Alpine Lunix"
                echo "------------------------"
                echo "41. Windows 11"
                echo "42. Windows 10"
                echo "43. Windows 7"
                echo "44. Windows Server 2022"
                echo "45. Windows Server 2019"
                echo "46. Windows Server 2016"
                echo "------------------------"
                read -p "请选择要重装的系统: " sys_choice

                case "$sys_choice" in
                    1)
                        dd_xitong_1
                        bash InstallNET.sh -debian 12
                        reboot
                        exit
                        ;;
                    2)
                        dd_xitong_1
                        bash InstallNET.sh -debian 11
                        reboot
                        exit
                        ;;
                    3)
                        dd_xitong_1
                        bash InstallNET.sh -debian 10
                        reboot
                        exit
                        ;;
                    4)
                        dd_xitong_1
                        bash InstallNET.sh -debian 9
                        reboot
                        exit
                        ;;
                    11)
                        dd_xitong_1
                        bash InstallNET.sh -ubuntu 24.04
                        reboot
                        exit
                        ;;
                    12)
                        dd_xitong_1
                        bash InstallNET.sh -ubuntu 22.04
                        reboot
                        exit
                        ;;
                    13)
                        dd_xitong_1
                        bash InstallNET.sh -ubuntu 20.04
                        reboot
                        exit
                        ;;
                    14)
                        dd_xitong_1
                        bash InstallNET.sh -ubuntu 18.04
                        reboot
                        exit
                        ;;
                    21)
                        dd_xitong_1
                        bash InstallNET.sh -centos 9
                        reboot
                        exit
                        ;;
                    22)
                        dd_xitong_1
                        bash InstallNET.sh -centos 8
                        reboot
                        exit
                        ;;   
                    23)
                        dd_xitong_1
                        bash InstallNET.sh -centos 7
                        reboot
                        exit
                        ;;
                    31)
                        dd_xitong_1
                        bash InstallNET.sh -alpine
                        reboot
                        exit
                        ;;
                    41)
                        dd_xitong_2
                        bash InstallNET.sh -windows 11 -lang "cn"
                        reboot
                        exit
                        ;;
                    42)
                        dd_xitong_2
                        bash InstallNET.sh -windows 10 -lang "cn"
                        reboot
                        exit
                        ;;
                    43)
                        dd_xitong_4
                        URL="https://massgrave.dev/windows_7_links"
                        web_content=$(wget -q -O - "$URL")
                        iso_link=$(echo "$web_content" | grep -oP '(?<=href=")[^"]*cn[^"]*windows_7[^"]*professional[^"]*x64[^"]*\.iso')
                        bash reinstall.sh windows --iso="$iso_link" --image-name='Windows 7 PROFESSIONAL'

                        reboot
                        exit
                        ;;
                    44)
                        dd_xitong_4
                        URL="https://massgrave.dev/windows_server_links"
                        web_content=$(wget -q -O - "$URL")
                        iso_link=$(echo "$web_content" | grep -oP '(?<=href=")[^"]*cn[^"]*windows_server[^"]*2022[^"]*x64[^"]*\.iso')
                        bash reinstall.sh windows --iso="$iso_link" --image-name='Windows Server 2022 SERVERDATACENTER'
                        reboot
                        exit
                        ;;
                    45)
                        dd_xitong_2
                        bash InstallNET.sh -windows 2019 -lang "cn"
                        reboot
                        exit
                        ;;
                    46)
                        dd_xitong_2
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
    local new_swap_size="$1"
    local available_disk_space

    # 验证输入
    if [[ -z "$new_swap_size" || ! "$new_swap_size" =~ ^[0-9]+$ ]]; then
        echo "错误：请提供一个有效的数字作为swap大小（以MB为单位）"
        return 1
    fi

    # 检查可用磁盘空间
    available_disk_space=$(df -m / | awk 'NR==2 {print $4}')
    if [ "$new_swap_size" -gt "$available_disk_space" ]; then
        echo "错误：没有足够的磁盘空间创建swap分区"
        echo "可用空间: ${available_disk_space}MB"
        echo "请求空间: ${new_swap_size}MB"
        return 1
    fi

    # 禁用现有swap
    echo "正在禁用并清理现有的swap分区..."
    swapoff -a

    # 删除旧的swap文件
    if [ -f /swapfile ]; then
        rm -f /swapfile
    fi

    echo "创建新的swap文件，大小为${new_swap_size}MB..."
    if ! dd if=/dev/zero of=/swapfile bs=1M count="$new_swap_size" status=progress; then
        echo "错误：创建swap文件失败"
        return 1
    fi

    chmod 600 /swapfile
    if ! mkswap /swapfile; then
        echo "错误：格式化swap文件失败"
        return 1
    fi

    if ! swapon /swapfile; then
        echo "错误：启用swap失败"
        return 1
    fi

    # 配置开机自动挂载
    if [ -f /etc/alpine-release ]; then
        echo "为Alpine Linux配置swap..."
        if ! grep -q "/swapfile" /etc/fstab; then
            echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
        fi
        if [ ! -d /etc/local.d ]; then
            mkdir -p /etc/local.d
        fi
        echo "nohup swapon /swapfile" > /etc/local.d/swap.start
        chmod +x /etc/local.d/swap.start
        rc-update add local
    else
        if ! grep -q "/swapfile" /etc/fstab; then
            echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
        fi
    fi

    echo "虚拟内存大小已调整为${new_swap_size}MB"
    free -h
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
        root_use
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

# 用户/密码生成器
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
        echo "1. 添加定时任务              2. 删除定时任务                  3. 编辑定时任务"
        echo "------------------------"
        echo "0. 返回上一级选单"
        echo "------------------------"
        read -p "请输入你的选择: " sub_choice

        case $sub_choice in
            1)
                read -p "请输入新任务的执行命令: " newquest
                echo "------------------------"
                echo "1. 每月任务                 2. 每周任务"
                echo "3. 每天任务                 4. 每小时任务"
                read -p "请输入你的选择: " dingshi

                case $dingshi in
                    1)
                        read -p "选择每月的几号执行任务？ (1-30): " day
                        (crontab -l ; echo "0 0 $day * * $newquest") | crontab - > /dev/null 2>&1
                        ;;
                    2)
                        read -p "选择周几执行任务？ (0-6，0代表星期日): " weekday
                        (crontab -l ; echo "0 0 * * $weekday $newquest") | crontab - > /dev/null 2>&1
                        ;;
                    3)
                        read -p "选择每天几点执行任务？（小时，0-23）: " hour
                        (crontab -l ; echo "0 $hour * * * $newquest") | crontab - > /dev/null 2>&1
                        ;;
                    4)
                        read -p "输入每小时的第几分钟执行任务？（分钟，0-60）: " minute
                        (crontab -l ; echo "$minute * * * * $newquest") | crontab - > /dev/null 2>&1
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
            3)
                crontab -e
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

#hosts解析列表
host_resolution(){
    while true; do
        echo "本机host解析列表"
        echo "如果你在这里添加解析匹配，将不再使用动态解析了"
        cat /etc/hosts
        echo ""
        echo "操作"
        echo "------------------------"
        echo "1. 添加新的解析              2. 删除解析地址"
        echo "------------------------"
        echo "0. 返回上一级选单"
        echo "------------------------"
        read -p "请输入你的选择: " host_dns

        case $host_dns in
            1)
                read -p "请输入新的解析记录 格式: 110.25.5.33 solin.pro : " addhost
                echo "$addhost" >> /etc/hosts

                ;;
            2)
                read -p "请输入需要删除的解析内容关键字: " delhost
                sed -i "/$delhost/d" /etc/hosts
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

#f2b_sshd
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

f2b_status_xxx() {
    docker exec -it fail2ban fail2ban-client status $xxx
}


f2b_status() {
     docker restart fail2ban
     sleep 3
     docker exec -it fail2ban fail2ban-client status
}

#fail2ban安装
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
        curl -sS -O https://raw.githubusercontent.com/kejilion/config/main/fail2ban/alpine-sshd.conf
        curl -sS -O https://raw.githubusercontent.com/kejilion/config/main/fail2ban/alpine-sshd-ddos.conf
        cd /path/to/fail2ban/config/fail2ban/jail.d/
        curl -sS -O https://raw.githubusercontent.com/kejilion/config/main/fail2ban/alpine-ssh.conf
    elif grep -qi 'CentOS' /etc/redhat-release; then
        cd /path/to/fail2ban/config/fail2ban/jail.d/
        curl -sS -O https://raw.githubusercontent.com/kejilion/config/main/fail2ban/centos-ssh.conf
    else
        install rsyslog
        systemctl start rsyslog
        systemctl enable rsyslog
        cd /path/to/fail2ban/config/fail2ban/jail.d/
        curl -sS -O https://raw.githubusercontent.com/kejilion/config/main/fail2ban/linux-ssh.conf
    fi
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

#fail2ban防御程序
fail2ban_defense(){
    if docker inspect fail2ban &>/dev/null ; then
        while true; do
            clear
            echo "SSH防御程序已启动"
            echo "------------------------"
            echo "1. 查看SSH拦截记录"
            echo "2. 日志实时监控"
            echo "------------------------"
            echo "9. 卸载防御程序"
            echo "------------------------"
            echo "0. 退出"
            echo "------------------------"
            read -p "请输入你的选择: " sub_choice
            case $sub_choice in
                1)
                    echo "------------------------"
                    f2b_sshd
                    echo "------------------------"
                    ;;
                2)
                    tail -f /path/to/fail2ban/config/log/fail2ban/fail2ban.log
                    break
                    ;;
                9)
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
        read -p "确定继续吗？(Y/N): " choice
        case "$choice" in
            [Yy])
                remove fail2ban
                rm -rf /etc/fail2ban
                echo "Fail2Ban防御程序已卸载"
                ;;
            [Nn])
                echo "已取消"
                ;;
            *)
                echo "无效的选择，请输入 Y 或 N。"
                ;;
        esac

    else

        clear
        echo "fail2ban是一个SSH防止暴力破解工具"
        echo "官网介绍: https://github.com/fail2ban/fail2ban"
        echo "------------------------------------------------"
        echo "工作原理：研判非法IP恶意高频访问SSH端口，自动进行IP封锁"
        echo "------------------------------------------------"
        read -p "确定继续吗？(Y/N): " choice

        case "$choice" in
        [Yy])
            clear
            if check_docker_installed; then
                echo "Docker is installed."
            else
                update_docker
            fi
            f2b_install_sshd

            cd ~
            f2b_status
            echo "Fail2Ban防御程序已开启"

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

#流量输出
output_status() {
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

}

#限流自动关机
limit_shutdown(){
    echo "当前流量使用情况，重启服务器流量计算会清零！"
    output_status
    echo "$output"

    # 检查是否存在 Limiting_Shut_down.sh 文件
    if [ -f ~/Limiting_Shut_down.sh ]; then
        # 获取 threshold_gb 的值
        threshold_gb=$(grep -oP 'threshold_gb=\K\d+' ~/Limiting_Shut_down.sh)
        echo -e "当前设置的限流阈值为 ${hang}${threshold_gb}${bai}GB"
    else
        echo -e "${hui}前未启用限流关机功能${bai}"
    fi

    echo
    echo "------------------------------------------------"
    echo "系统每分钟会检测实际流量是否到达阈值，到达后会自动关闭服务器！每月1日重置流量重启服务器。"
    read -p "1. 开启限流关机功能    2. 停用限流关机功能    0. 退出  : " Limiting

    case "$Limiting" in
        1)
            # 输入新的虚拟内存大小
            echo "如果实际服务器就100G流量，可设置阈值为95G，提前关机，以免出现流量误差或溢出."
            read -p "请输入流量阈值（单位为GB）: " threshold_gb
            cd ~
            curl -Ss -O https://raw.githubusercontent.com/zxl2008gz/sh/main/Limiting_Shut_down.sh
            chmod +x ~/Limiting_Shut_down.sh
            sed -i "s/110/$threshold_gb/g" ~/Limiting_Shut_down.sh
            crontab -l | grep -v '~/Limiting_Shut_down.sh' | crontab -
            (crontab -l ; echo "* * * * * ~/Limiting_Shut_down.sh") | crontab - > /dev/null 2>&1
            crontab -l | grep -v 'reboot' | crontab -
            (crontab -l ; echo "0 1 1 * * reboot") | crontab - > /dev/null 2>&1
            echo "限流关机已设置"

            ;;
        0)
            echo "已取消"
            ;;
        2)
            crontab -l | grep -v '~/Limiting_Shut_down.sh' | crontab -
            crontab -l | grep -v 'reboot' | crontab -
            rm ~/Limiting_Shut_down.sh
            echo "已关闭限流关机功能"
            ;;
        *)
            echo "无效的选择，请输入 Y 或 N。"
            ;;
    esac
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

#ssh私钥
add_sshkey() {

    # ssh-keygen -t rsa -b 4096 -C "xxxx@gmail.com" -f /root/.ssh/sshkey -N ""
    ssh-keygen -t ed25519 -C "xxxx@gmail.com" -f /root/.ssh/sshkey -N ""

    cat ~/.ssh/sshkey.pub >> ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys

    # 获取IP地址
    read ipv4_address ipv6_address < <(get_ip_address)

    echo -e "私钥信息已生成，务必复制保存，可保存成 ${huang}${ipv4_address}_ssh.key${bai} 文件，用于以后的SSH登录"

    echo "--------------------------------"
    cat ~/.ssh/sshkey
    echo "--------------------------------"

    sed -i -e 's/^\s*#\?\s*PermitRootLogin .*/PermitRootLogin prohibit-password/' \
        -e 's/^\s*#\?\s*PasswordAuthentication .*/PasswordAuthentication no/' \
        -e 's/^\s*#\?\s*PubkeyAuthentication .*/PubkeyAuthentication yes/' \
        -e 's/^\s*#\?\s*ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
    rm -rf /etc/ssh/sshd_config.d/* /etc/ssh/ssh_config.d/*
    echo -e "${lv}ROOT私钥登录已开启，已关闭ROOT密码登录，重连将会生效${bai}"

}

#ROOT私钥登录模式
root_key(){
    echo "ROOT私钥登录模式"
    echo "------------------------------------------------"
    echo "将会生成密钥对，更安全的方式SSH登录"
    read -p "确定继续吗？(Y/N): " choice

    case "$choice" in
    [Yy])
        clear
        add_sshkey
        ;;
    [Nn])
        echo "已取消"
        ;;
    *)
        echo "无效的选择，请输入 Y 或 N。"
        ;;
    esac
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
        echo -e "20. 定时任务管理 ${huang}NEW${bai}"
        echo "------------------------"
        echo "21. 本机host解析"
        echo "22. fail2banSSH防御程序"
        echo "23. 限流自动关机"
        echo "24. ROOT私钥登录模式"
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
                root_use
                set_rootpasswd
                break_end
                ;;
            4)
                clear
                root_use
                install_python
                break_end
                ;;
            5)
                clear
                root_use
                iptables_open
                remove iptables-persistent ufw firewalld iptables-services > /dev/null 2>&1
                echo "端口已全部开放"
                break_end
                ;;
            6)
                clear
                root_use
                modify_ssh_port
                break_end
                ;;
            7)
                clear
                root_use
                set_dns
                break_end
                ;;
            8)
                DD_xitong
                break_end
                ;;  
            9)
                clear
                root_use
                create_new_user
                break_end
                ;;  
            10)
                clear
                root_use
                switch_ipv4_ipv6
                break_end
                ;;   
            11)
                clear
                ss -tulnape
                break_end
                ;;
            12)
                root_use
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
                root_use
                set_time_zone
                ;;
            16)
                root_use
                update_bbr3
                break_end
                ;;
            17)
                root_use
                ufw_manage
                break_end
                ;;
            18)
                clear
                root_use
                modify_hostname
                break_end
                ;;
            19)
                root_use
                get_current_source
                update_source
                break_end
                ;;
            20)
                root_use
                scheduled_tasks
                break_end
                ;;
            21)
                root_use
                host_resolution
                break_end
                ;;
            22)
                root_use
                fail2ban_defense
                break_end
                ;;
            23)
                root_use
                limit_shutdown
                break_end
                ;;
            24)
                root_use
                root_key
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

# 主逻辑
case "$1" in
        work)
            work_area
            ;;
        tool)
            system_tool
            ;;
        *)
            echo "Usage: $0 {work|tool}"
            exit 1
esac
