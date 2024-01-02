#!/bin/bash

# 判断是否已经存在 alias
if ! grep -q "alias k='./Solin.sh'" ~/.bashrc; then
    # 如果不存在，则添加 alias
    echo "alias k='./Solin.sh'" >> ~/.bashrc
    source ~/.bashrc
else
    clear
fi


ipv4_address() {
  ipv4_address=$(curl -s ipv4.ip.sb)
}


