#!/bin/bash

# 判断是否已经存在 alias
if ! grep -q "alias k='./solin.sh'" ~/.bashrc; then
    # 如果不存在，则添加 alias
    echo "alias k='./solin.sh'" >> ~/.bashrc
    # 重新加载.bashrc文件以应用更改
    source ~/.bashrc
else
    # 清除屏幕
    clear
fi

# 主循环，用于显示菜单并处理用户输入
while true; do
    clear  # 清除屏幕

    # 显示菜单
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

    # 读取用户输入
    read -p "请选择操作 [0-13]：" op
    case $op in
        1)
            # 系统信息查询逻辑
            ;;
        2)
            # 系统更新逻辑
            ;;
        3)
            # 系统清理逻辑
            ;;
        # ... 其他选项的逻辑 ...
        0)
            # 退出脚本
            break
            ;;
        *)
            echo "无效的选项，请重新输入！"
            ;;
    esac
done
