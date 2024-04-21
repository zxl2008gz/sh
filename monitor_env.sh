#!/bin/bash

# 脚本参数：传递域名作为第一个参数
domain="$1"
env_path="/home/docker/html/$domain/dujiaoka/.env"
last_hash=$(md5sum "$env_path" | cut -d ' ' -f1)
logfile="/var/log/env_monitor.log"

# 确保日志文件存在
touch "$logfile"

# 监控.env文件的修改
echo "正在监控文件变化 $env_path" >> "$logfile"
inotifywait -m -e modify "$env_path" | while read path action file; do
    current_hash=$(md5sum "$env_path" | cut -d ' ' -f1)
    if [ "$current_hash" != "$last_hash" ]; then
        sed -i 's/^ADMIN_HTTPS=false/ADMIN_HTTPS=true/g' "$env_path"
        echo "$(date) - 检测到 $file 被 $action，ADMIN_HTTPS 设置已更新为 true" >> "$logfile"
        last_hash=$current_hash
    fi
done &

# 将后台进程PID写入日志
echo $! > "/var/run/env_monitor.pid"
