#!/bin/bash

# 判断是否已经存在 alias
if ! grep -q "alias k='./solin.sh'" ~/.bashrc; then
    # 如果不存在，则添加 alias
    echo "alias k='./solin.sh'" >> ~/.bashrc
    source ~/.bashrc
else
    clear
fi


ipv4_address() {
  ipv4_address=$(curl -s ipv4.ip.sb)
}


# 这个install函数是一个通用的软件包安装器，它自动检测Linux系统上的包管理器（apt或yum），并尝试安装用户指定的一个或多个软件包。
# 如果没有提供任何软件包名，或者系统上没有已知的包管理器，它将返回错误。这个函数可以在多种基于Debian和基于RedHat的Linux发行版上工作。
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

# install_dependency 函数是一个便利的封装，用于安装一组常用工具。通过调用已定义的 install 函数，它简化了多个软件包的安装过程。
install_dependency() {
      clear
      install wget socat unzip tar
}

# remove函数是一个通用的软件包卸载器，它自动检测Linux系统上的包管理器（apt或yum），并尝试移除用户指定的一个或多个软件包。
# 如果没有提供任何软件包名，或者系统上没有已知的包管理器，它将返回错误。这个函数可以在多种基于Debian和基于RedHat的Linux发行版上工作。
# 它尝试彻底清理软件包和相关配置文件（使用apt purge而不是仅仅apt remove），以确保系统的整洁。
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
        else
            echo "未知的包管理器!"
            return 1
        fi
    done

    return 0
}

# break_end 函数是一个用户友好的结束提示，用于在脚本或一系列命令执行完毕后通知用户并等待其响应以继续。
# 它通过打印彩色的“操作完成”消息、等待用户按键并清除屏幕来实现这一点。这种函数在交互式脚本中非常有用，可以提供更好的用户体验。
break_end() {
      echo -e "\033[0;32m操作完成\033[0m"
      echo "按任意键继续..."
      read -n 1 -s -r -p ""
      echo ""
      clear
}

# 这段代码的目的是执行solin.sh脚本，并且在执行完后退出当前的shell。
solin() {
            cd ~
            ./solin.sh
            exit
}


# 定义要检测的端口
check_port() {    
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
            kejilion

        fi
    else
        echo ""
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



while true; do
clear

echo -e "\033[96m_  _ ____  _ _ _    _ ____ _  _ "
echo "|_  |___  | | |    | |  | |\ | "
echo "  | _ |___ _| | |___ | |__| | \| "
echo "                                "
echo -e "\033[96m科技lion一键脚本工具 v2.1.5 （支持Ubuntu/Debian/CentOS系统）\033[0m"
echo -e "\033[96m-输入\033[93mk\033[96m可快速启动此脚本-\033[0m"
echo "------------------------"
echo "1. 系统信息查询"
echo "2. 系统更新"
echo "3. 系统清理"
echo "4. 常用工具 ▶"
echo "5. BBR管理 ▶"
echo "6. Docker管理 ▶ "
echo "7. WARP管理 ▶ 解锁ChatGPT Netflix"
echo "8. 测试脚本合集 ▶ "
echo "9. 甲骨文云脚本合集 ▶ "
echo -e "\033[33m10. LDNMP建站 ▶ \033[0m"
echo "11. 面板工具 ▶ "
echo "12. 我的工作区 ▶ "
echo "13. 系统工具 ▶ "
echo "------------------------"
echo "00. 脚本更新"
echo "------------------------"
echo "0. 退出脚本"
echo "------------------------"
read -p "请输入你的选择: " choice

