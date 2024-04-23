#!/bin/bash

# 函数：退出
break_end() {
    echo -e "\033[0;32m操作完成\033[0m"
    echo "按任意键继续..."
    read -n 1 -s -r -p ""
    echo
    clear
}

# 安全执行命令的函数
safe_exec() {
    local output
    output=$(eval "$@" 2>&1)
    local status=$?
    if [ $status -ne 0 ]; then
        echo "Error running command: $@" >&2
        echo "Output: $output" >&2
        return $status
    fi
    echo "$output"
}

# 获取数据库容器的名称
get_db_container_name() {
    local db_image_keyword="$1"
    safe_exec docker ps --format "{{.Names}}\t{{.Image}}" | grep "$db_image_keyword" | awk '{print $1}'
}

# 获取数据库配置值
get_config_value() {
    local var_name="$1"
    local container_name="$2"
    safe_exec docker exec "$container_name" /bin/sh -c "echo \${$var_name}"
}

# 函数：获取数据库凭据
get_db_credentials() {
    local container_name=$1
    local user=$(get_config_value 'MYSQL_USER' "$container_name")
    local password=$(get_config_value 'MYSQL_PASSWORD' "$container_name")
    local root_password=$(get_config_value 'MYSQL_ROOT_PASSWORD' "$container_name")
    echo "$user" "$password" "$root_password"
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

# 主菜单系统
manager_mysql() {
    local container_name_keyword="$1"
    local container_name=$(get_db_container_name "$container_name_keyword")
    if [ -z "$container_name" ]; then
        echo "找不到对应的数据库容器。"
        return 1
    fi
    IFS=' ' read -r user password root_password <<< $(get_db_credentials "$container_name")
    local credentials=($user $password $root_password)
    while true; do
        clear
        mysql_display "$container_name" "${credentials[2]}"
        echo "请选择您要执行的操作："
        echo "1. 创建数据库"
        echo "2. 删除数据库"
        echo "3. 导入数据库"
        echo "4. 查询和修改数据库信息"
        echo "0. 返回上一级菜单"

        read -p "请输入你的选择: " option

        case $option in
            1)
                read -p "请输入数据库名称: " dbname
                create_database_and_grant "$container_name_mysql" "$dbname" "${credentials[0]}" "${credentials[1]}" "${credentials[2]}"
                break_end
                ;;
            2)
                read -p "请输入要删除的数据库名称：" dbname
                delete_database "$container_name_mysql" "$dbname" "${credentials[2]}" "${credentials[0]}"
                break_end
                ;;
            3)
                read -p "请输入数据文件的完整路径：" datafile
                read -p "请输入数据库名称: " dbname
                import_database "$container_name_mysql" "$dbname" "${credentials[1]}" "$datafile"
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
    delete)
        container_name1="$2"
	dbname="$3"
        container_name_mysql=$(get_db_container_name "$container_name1")
        credentials=($(get_db_credentials "$container_name_mysql"))
        delete_database "$container_name_mysql" "$dbname" "${credentials[2]}" "${credentials[0]}"
        ;;
    manage)
        manager_mysql "$2"
        ;;
    *)
        echo "Usage: $0 {create|delete|manage} ..."
        exit 1
esac
