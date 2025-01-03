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
