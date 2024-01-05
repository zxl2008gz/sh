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
