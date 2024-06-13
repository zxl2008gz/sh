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
                dnf -y update && dnf install -y "$package"
            elif command -v yum &>/dev/null; then
                yum -y update && yum -y install "$package"
            elif command -v apt &>/dev/null; then
                apt update -y && apt install -y "$package"
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
        if command -v dnf &>/dev/null; then
            dnf remove -y "${package}*"
        elif command -v yum &>/dev/null; then
            yum remove -y "${package}*"
        elif command -v apt &>/dev/null; then
            apt purge -y "${package}*"
        elif command -v apk &>/dev/null; then
            apk del "${package}*"
        else
            echo "未知的包管理器!"
            return 1
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

# 检查数据库是否存在
database_exists() {
    local container_name=$1
    local dbname=$2
    local dbroot_password=$3

    local check_command="SHOW DATABASES LIKE '$dbname';"
    if docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root -e "$check_command" | grep -q "$dbname"; then
        return 0
    else
        return 1
    fi
}

# 查询数据库并列出所有表
query_database() {
    local container_name=$1
    local dbroot_password=$2
    local dbname=$3

    local query="SHOW TABLES"

    if ! output=$(docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root -e "$query" "$dbname" 2>&1); then
        echo "Error: Failed to query database. MySQL said: $output"
        return 1
    fi
    clear
    echo "$output"
}

# 创建数据库并授权，如果存在则先删除
create_database_and_grant() {
    local container_name=$1
    local dbname=$2
    local dbuser=$3
    local dbuser_password=$4
    local dbroot_password=$5

    # 检查数据库是否存在
    if database_exists "$container_name" "$dbname" "$dbroot_password"; then
        echo "Database '$dbname' already exists."
        if ask_confirmation "Do you want to delete and recreate it?"; then
            echo "Deleting and recreating database..."
            delete_database "$container_name" "$dbname" "$dbroot_password" "$dbuser"  # 确保 delete_database 能正确处理不存在的情况
        else
            echo "Operation canceled by the user."
            return 1
        fi
    fi

    # 创建数据库
    local create_db_command="CREATE DATABASE IF NOT EXISTS \`${dbname}\`;"
    if ! output=$(docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root -e "$create_db_command" 2>&1); then
        echo "Error: Failed to create database. MySQL said: $output"
        return 1
    fi

    # 创建用户并授权
    local grant_command="CREATE USER IF NOT EXISTS '${dbuser}'@'%' IDENTIFIED BY '${dbuser_password}';"
    grant_command+=" GRANT ALL PRIVILEGES ON \`${dbname}\`.* TO '${dbuser}'@'%';"
    grant_command+=" FLUSH PRIVILEGES;"

    if ! output=$(docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root -e "$grant_command" 2>&1); then
        echo "Error: Failed to set privileges. MySQL said: $output"
        return 1
    fi

    echo "Database '${dbname}' created and privileges granted to user '${dbuser}'."
}

# 删除数据库并解除权限
delete_database() {
    local container_name=$1
    local dbname=$2
    local dbroot_password=$3
    local dbuser=$4  # 添加了 dbuser 参数

    # 列出所有受保护的系统数据库
    declare -a system_dbs=("information_schema" "mysql" "performance_schema" "sys")

    # 检查是否尝试删除系统数据库
    if [[ " ${system_dbs[*]} " =~ " ${dbname} " ]]; then
        echo "Error: Access to system schema '${dbname}' is rejected."
        return 1
    fi

    # 删除数据库
    local drop_db_command="DROP DATABASE IF EXISTS \`${dbname}\`;"
    if ! output=$(docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" \
                   mysql -u root -e "$drop_db_command" 2>&1); then
        echo "Error: Failed to delete database. MySQL said: $output"
        return 1
    fi

    # 检查用户是否有权限
    if ! grants_output=$(docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" \
                         mysql -u root -e "SHOW GRANTS FOR '${dbuser}'@'%';" 2>&1); then
        echo "User '${dbuser}'@'%' has no privileges or does not exist, skipping revoke."
    else
        # 解除该数据库的所有权限
        local revoke_privileges_command="REVOKE ALL PRIVILEGES ON \`${dbname}\`.* FROM '${dbuser}'@'%';"
        revoke_privileges_command+=" DROP USER IF EXISTS '${dbuser}'@'%';"  # 删除用户
        revoke_privileges_command+=" FLUSH PRIVILEGES;"
        
        if ! output=$(docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" \
                       mysql -u root -e "$revoke_privileges_command" 2>&1); then
            echo "Error: Failed to revoke privileges. MySQL said: $output"
            return 1
        fi
    fi

    echo "Database '${dbname}' deleted and user '${dbuser}'@'%' privileges revoked successfully."
}

# 导入数据库
import_database() {
    local container_name=$1
    local dbname=$2
    local dbuser_password=$3
    local datafile=$4

    if ! output=$(docker exec -i -e MYSQL_PWD="$dbuser_password" "$container_name" mysql -u root "$dbname" < "$datafile" 2>&1); then
        echo "Error: Failed to import data to database. MySQL said: $output"
        return 1
    fi
    echo "Data successfully imported to database '$dbname'."
}

# 数据库显示列表
mysql_display() {
    local container_name1="$1"
    local credentials1="$2"
    echo "可用的数据库容器:"
    echo "---------------------------------------------"
    printf "%-30s %-20s\n" "数据库列表" "容器名称"
    echo "---------------------------------------------"

    # 列出所有运行的容器以及对应的镜像名称

    docker ps --format "{{.Names}}\t{{.Image}}" | grep "$container_name1" | while read -r container_name image_name; do
        databases=$(docker exec -e MYSQL_PWD="$credentials1" "$container_name" mysql -u root -e 'SHOW DATABASES;' | sed '1d')
        if [ -n "$databases" ]; then
            echo "$databases" | while read db; do
                printf "%-25s %-20s\n" "$db" "$container_name"
            done
        else
            echo "没有找到数据库。"
        fi
        echo "---------------------------------------------"
    done
}

# 函数：通过复制表来重命名数据库
rename_database() {
    local old_dbname=$1
    local new_dbname=$2
    local container_name=$3
    local dbroot_password=$4

    # 确认操作
    echo "您确定要将数据库 '$old_dbname' 重命名为 '$new_dbname' 吗？这将创建一个新的数据库并转移所有表。(Y/N):"
    read confirmation
    if [[ "$confirmation" =~ ^[Yy]$ ]]; then
        # 创建新数据库
        local create_db_command="CREATE DATABASE \`$new_dbname\`;"
        docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root -e "$create_db_command"

        # 获取旧数据库中所有表的列表
        local tables=$(docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root -e "SHOW TABLES IN \`$old_dbname\`;" | awk 'NR > 1')

        # 复制每个表到新数据库
        for table in $tables; do
            local rename_table_command="RENAME TABLE \`$old_dbname\`.\`$table\` TO \`$new_dbname\`.\`$table\`;"
            docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root -e "$rename_table_command"
        done

        # 删除旧数据库
        local drop_db_command="DROP DATABASE \`$old_dbname\`;"
        docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root -e "$drop_db_command"

        echo "数据库已成功从 '$old_dbname' 重命名为 '$new_dbname'."
    else
        echo "取消数据库重命名操作。"
    fi
}

# 函数: 修改表名
rename_table() {
    local dbname="$1"
    local old_table_name="$2"
    local new_table_name="$3"
    local container_name="$4"
    local dbuser_password="$5"

    if ask_confirmation "确定要重命名表 '$old_table_name' 为 '$new_table_name' 吗?"; then
        local rename_table_command="RENAME TABLE \`${dbname}\`.\`${old_table_name}\` TO \`${dbname}\`.\`${new_table_name}\`;"
        if ! output=$(docker exec -e MYSQL_PWD="$dbuser_password" "$container_name" mysql -u root -D "$dbname" -e "$rename_table_command" 2>&1); then
            echo "错误: 无法重命名表。MySQL 报告: $output"
            return 1
        fi
        echo "表 '$old_table_name' 已重命名为 '$new_table_name'."
    else
        echo "操作已取消。"
    fi
}

# 修改数据库表操作
command_midif_db() {
    local container_name_mysql=$1
    local credentials1=$2
    local dbname=$3

    query_database "$container_name_mysql" "$credentials1" "$dbname"
    read -p "请输入要修改数据表的数据库表名称: " old_table_name
    read -p "请输入新数据库表名称: " new_table_name
    rename_table "$dbname" "$old_table_name" "$new_table_name" "$container_name_mysql" "$credentials1"
    clear
    query_database "$container_name_mysql" "$credentials1" "$dbname"
}

# 函数：列出指定数据库内指定表的所有数据
list_table_data() {
    local container_name=$1
    local dbroot_password=$2
    local dbname=$3
    local table_name=$4

    echo "Listing data from table '$table_name' in database '$dbname'..."

    local query_command="SELECT * FROM $table_name;"

    if ! output=$(docker exec -e MYSQL_PWD="$dbroot_password" "$container_name" mysql -u root -D "$dbname" -e "$query_command" 2>&1); then
        echo "Error: Failed to list data. MySQL said: $output"
        return 1
    fi

    echo "$output"
}

# 函数: 修改指定数据行的特定列
modify_column_data() {
    local dbname="$1"
    local table_name="$2"
    local primary_key_column="$3"
    local primary_key_value="$4"
    local column_name="$5"
    local new_value="$6"
    local container_name="$7"
    local dbuser_password="$8"

    # 构建更新命令
    local update_command="UPDATE \`${dbname}\`.\`${table_name}\` SET \`${column_name}\`='${new_value}' WHERE \`${primary_key_column}\`='${primary_key_value}';"
    
    echo "Executing: $update_command"
    
    # 执行更新命令
    if ! output=$(docker exec -i -e MYSQL_PWD="$dbuser_password" "$container_name" mysql -u root -D "$dbname" -e "$update_command" 2>&1); then
        echo "Error: Failed to modify data. MySQL said: $output"
        return 1
    fi
    echo "Column data updated successfully."
}

# 函数: 修改指定数据内容
command_midif_data() {
    local container_name_mysql=$1
    local credentials1=$2
    local dbname=$3

    query_database "$container_name_mysql" "$credentials1" "$dbname"
    read -p "请输入数据库表名称: " table_name
    list_table_data "$container_name_mysql" "$credentials1" "$dbname" "$table_name"
    # 询问用户要修改哪行数据
    read -p "请输入需要修改的主键列名称:" primary_key
    read -p "请输入需要修改的主键值,(例如:ID=1):" primary_key_value
    read -p "请输入想要更新的列名:" row_name
    read -p "请输入需要修改新的值(new_value):" new_key_value
    modify_column_data "$dbname" "$table_name" "$primary_key" "$primary_key_value" "$row_name" "$new_key_value" "$container_name_mysql" "$credentials1"
    clear
    list_table_data "$container_name_mysql" "$credentials1" "$dbname" "$table_name"
    break_end
}

# 修改数据库
modif_db(){
    local container_name1="$1"
    local credentials1="$2"
    local container_name_mysql="$3"
    while true; do
        clear
        mysql_display "$container_name1" "$credentials1"
        echo "请选择您要执行的操作："
        echo "1. 查询指定数据库列表"
        echo "2. 修改指定数据库名称"
        echo "3. 修改指定数据库表名"
        echo "4. 修改指定数据库指定数据"
        echo "0. 返回上一级菜单"
        read -p "请输入你的选择: " choice
        case $choice in
            1)
                read -p "请输入要查询的数据库名称: " dbname
                query_database "$container_name_mysql" "$credentials1" "$dbname"
                break_end
                ;;
            2)
                read -p "请输入要修改的原数据库名称: " old_dbname
                read -p "请输入新数据库名称: " new_dbname
                rename_database "$old_dbname" "$new_dbname" "$container_name_mysql" "$credentials1" 
                break_end               
                ;;
            3)
                read -p "请输入要修改数据表的数据库名称: " dbname
                command_midif_db "$container_name_mysql" "$credentials1" "$dbname"
                break_end
                ;;
            4)
                read -p "请输入要修改数据表的数据库名称: " dbname
                command_midif_data "$container_name_mysql" "$credentials1" "$dbname"
                ;;
            0)
                break
                ;;
            *)
                echo "无效的选项，请重新输入"
                ;;
        esac
    done
}

# 检查Docker是否安装
check_docker_installed_db() {
    if ! command -v docker &>/dev/null; then
        echo "Docker 未安装。"
        return 1
    fi
}

# 函数：获取用户输入或默认数据，20秒后无输入则使用默认值，如果开始输入则等待完成
get_default_data_db() {
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

# 获取持久化路径
get_mysql_volume_path() {
    local container_name=$1  # 例如：mysql_container

    # 使用 docker inspect 命令获取挂载卷信息
    local volume_path=$(docker inspect --format='{{range .Mounts}}{{println .Source .Destination}}{{end}}' $container_name | grep '/var/lib/mysql' | awk '{print $1}')
    
    # 输出路径
    echo $volume_path
}

# 备份数据库
beifen_mysql() {

    local container_name="$1"  # MySQL容器名称
    local backup_path="$2"     # 数据库备份的路径
    local dbrootpasswd="$3"
    # 确保备份目录存在
    mkdir -p "$backup_path"

    # 确保提供了容器名称和备份路径
    if [[  -z "$backup_path" ]]; then
        echo "Usage: reset_mysql_container <container_name> <backup_path>"
        return 1
    fi

    # 生成备份文件名，包含当前日期和时间
    local current_time=$(date +"%Y%m%d_%H%M%S")
    local backup_file="db_backup_$current_time.sql"

    # 备份数据库
    echo "正在备份数据库..."
    docker exec "$container_name" mysqldump --all-databases --extended-insert --user=root --password="$dbrootpasswd" > "$backup_path/$backup_file"
    
    echo "MySQL容器备份存储在：$backup_path/$backup_file"

}

# 函数：重置MySQL容器及其数据，并备份数据库
reset_mysql_container() {
    local container_name="$1"  # MySQL容器名称
    local backup_path="$2"     # 数据库备份的路径
    local dbrootpasswd="$3"
    local container_path=$(get_mysql_volume_path $container_name)

    # 确保提供了容器名称和备份路径
    if [[ -z "$container_name" ]]; then
        echo "Usage: reset_mysql_container <container_name> <container_path>"
        return 1
    fi
    
    #备份
    beifen_mysql $container_name $backup_path $dbrootpasswd

    # 停止并删除MySQL容器
    echo "正在停止并删除MySQL容器..."
    docker stop "$container_name"
    docker rm "$container_name"

    # 删除与MySQL容器关联的所有数据卷
    echo "正在删除与MySQL容器关联的所有数据卷..."
    sudo rm -rf "$container_path"

    echo "MySQL容器及其数据卷已删除。备份存储在：$backup_path/$backup_file"
}

# 安装更新MYSQL环境
update_db() {
    local dbroot_password='$1'
    db_mysql_path=$(get_default_data_db "请输入MYSQL的路径" "/home/docker" "20") 
    # 创建必要的目录和文件
    if [ -z "$db_mysql_path" ]; then
        echo "Error: db_mysql_path is not set."
        exit 1
    fi

    mkdir -p "$db_mysql_path" && cd "$db_mysql_path" && \
    mkdir -p mysql mysql_backup && \
    touch docker-compose-mysql.yml

    mysql_container_name=$(get_default_data_db "请输入MYSQL的容器名" "mysql" "20") 
    mysql_container_image=$(get_default_data_db "请输入MYSQL的镜像名" "mysql" "20")
    mysql_container_volume=$(get_default_data_db "请输入持久化volume路径" "./mysql" "20")

    mysql_container_rootwd=$(get_default_data_db "请设置MYSQL的容器的root密码" "mysqlwebroot" "20") 
    mysql_container_dbuse=$(get_default_data_db "请设置MYSQL的容器的用户名" "mysqluse" "20")
    mysql_container_passwd=$(get_default_data_db "请设置MYSQL的容器的用户密码" "mysqlpasswd" "20")

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

    reset_mysql_container "$mysql_container_name" "$db_mysql_path/mysql_backup" "$dbroot_password"
}

# 安装更新mysql环境
install_db_mysql() {
    local dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /home/docker/docker-compose-mysql.yml | tr -d '[:space:]')
    update_db "$dbrootpasswd"
    cd $db_mysql_path && docker-compose -f docker-compose-mysql.yml up -d
    echo -e "安装信息如下： \n新的用户名: '"$mysql_container_dbuse"' \n新的用户密码: '"$mysql_container_passwd"' \n新的root密码: '"$mysql_container_rootwd"' "
    sleep 5
       
}

# 函数：检查 MySQL 容器是否运行
check_mysql_installed_db() {
    if docker ps | grep -q mysql; then
        echo "MySQL 已安装并且正在运行."
        return 0  # MySQL 已安装并且正在运行
    else
        echo "MySQL 未安装或未运行"
        return 1  # MySQL 未安装或未运行
    fi
}

#备份数据文件
benfen_db_mysql() {
    local container_name1="$1"
    local container_name_mysql=$(get_db_container_name "$container_name1")
    local credentials=($(get_db_credentials "$container_name_mysql"))
    mysql_display "$container_name1" "${credentials[2]}"
    read -p "请输入要备份的数据库的容器名称: " container_save_name
    beifen_mysql $container_save_name "/home/docker/mysql_backup" "${credentials[2]}"
}

# MYSQL管理器
manager_db_mysql() {
    local container_name1="$1"
    local container_name_mysql=$(get_db_container_name "$container_name1")
    local credentials=($(get_db_credentials "$container_name_mysql"))
    while true; do
        clear
        echo "▶ MYSQL管理器"
        echo "------------------------"
        echo "1. 安装更新MYSQL环境(会关闭脚本)"
        echo "------------------------"				
        echo "2. 查看MYSQL全局状态"
        echo "------------------------"
        echo "3. MYSQL容器管理 ▶"
        echo "------------------------"		
        echo "4. MYSQL备份 ▶"
        echo "------------------------"				
        echo "21. 卸载MYSQL环境"	
        echo "------------------------"		
        echo "0. 返回主菜单"
        echo "------------------------"
        read -p "请输入你的选择: " sub_choice

        case $sub_choice in
            1)
                # 检查 MySQL 是否已经安装并运行
                if check_mysql_installed_db; then
                    echo "Running 'mysql --version' to check the installed MySQL version:"
                    docker exec mysql mysql --version
                    if ask_confirmation "MySQL已安装，确定要更新MySQL吗?（更新后用户名等信息会变）"; then
                        install_db_mysql 
                    else
                        echo "操作已取消。"
                    fi
                else
                    # 如果 MySQL 容器未运行，检查 Docker 是否安装
                    if check_docker_installed_db; then
                        echo "MySQL container is not running. Attempting to start or install MySQL container."
                        install_db_mysql
                    else
                        echo "Docker is not installed."
                        update_docker
                    fi
                fi
                # 切换到一个一致的目录（例如，家目录）
                cd ~ || exit
                exec "$SHELL"
                ;;
            2)
                clear
                mysql_display "$container_name1" "${credentials[2]}"
                break_end
                ;;
            3)
                manager_mysql $container_name1
                ;;
            4)
                clear
                benfen_db_mysql "$container_name1"
                break_end
                ;;
            21)
                reset_mysql_container "$container_name_mysql" "$db_mysql_path/mysql_backup"
                break_end
                ;;
            0)
                break
                ;;
            *)
                echo "无效的选项，请重新输入！"
                ;;
        esac
    done
}

# 主菜单系统
manager_mysql() {
    local container_name1="$1"
    local container_name_mysql=$(get_db_container_name "$container_name1")
    local credentials=($(get_db_credentials "$container_name_mysql"))
    while true; do
        clear
        mysql_display "$container_name1" "${credentials[2]}"
        echo "请选择您要执行的操作："
        echo "1. 创建新的数据库"
        echo "2. 删除指定数据库"
        echo "3. 导入指定数据库"
        echo "4. 查询和修改数据库信息"
        echo "0. 返回上一级菜单"

        read -p "请输入你的选择: " option

        case $option in
            1)
                read -p "请输入新数据库名称: " dbname
                read -p "请输入存放新数据库的容器: " container_save_name
                create_database_and_grant "$container_save_name" "$dbname" "${credentials[0]}" "${credentials[1]}" "${credentials[2]}"
                break_end
                ;;
            2)
                read -p "请输入要删除的数据库名称：" dbname
                read -p "请输入要删除数据库的容器: " container_save_name
                delete_database "$container_save_name" "$dbname" "${credentials[2]}" "${credentials[0]}"
                break_end
                ;;
            3)
                read -p "请输入要导入数据文件的完整路径：" datafile
                read -p "请输入要导入数据库名称: " dbname
                read -p "请输入要导入数据库的容器名称: " container_save_name
                import_database "$container_save_name" "$dbname" "${credentials[1]}" "$datafile"
                break_end
                ;;
            4)
                modif_db "$container_name1" "${credentials[2]}" "$container_name_mysql"
                ;;
            0)
                break
                ;;
            *)
                echo "无效的选项，请重新输入"
                ;;
        esac
    done
}

# 主逻辑
case "$1" in
    create)
        container_name1="$2"
	    dbname="$3"
        container_name_mysql=$(get_db_container_name "$container_name1")
        credentials=($(get_db_credentials "$container_name_mysql"))
        create_database_and_grant "$container_name_mysql" "$dbname" "${credentials[0]}" "${credentials[1]}" "${credentials[2]}"
        ;;
    install)
        install_db_mysql "$2" 
        ;;
    delete)
        container_name1="$2"
	    dbname="$3"
        container_name_mysql=$(get_db_container_name "$container_name1")
        credentials=($(get_db_credentials "$container_name_mysql"))
        delete_database "$container_name_mysql" "$dbname" "${credentials[2]}" "${credentials[0]}"
        ;;
    manage)
        manager_db_mysql "$2"
        ;;
    *)
        echo "Usage: $0 {install|delete|manage} ..."
        exit 1
esac
