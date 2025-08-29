#!/bin/bash
# 模拟 rclone 命令用于测试

echo "模拟 rclone 命令执行:"
echo "命令: rclone $*"

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        copy|sync)
            OPERATION="$1"
            shift
            ;;
        --*)
            # 跳过选项
            shift
            ;;
        *)
            if [ -z "${SOURCE:-}" ]; then
                SOURCE="$1"
            elif [ -z "${DEST:-}" ]; then
                DEST="$1"
            fi
            shift
            ;;
    esac
done

echo "操作: $OPERATION"
echo "源: $SOURCE"
echo "目标: $DEST"

# 模拟复制操作
if [ -d "$SOURCE" ]; then
    echo "复制目录内容:"
    find "$SOURCE" -type f | while read -r file; do
        echo "  复制: $file"
        # 实际复制文件到目标（去掉 remote: 前缀）
        target_path=$(echo "$DEST" | sed 's/^[^:]*://')
        mkdir -p "$target_path"
        cp -r "$SOURCE"/* "$target_path/" 2>/dev/null || true
    done
    echo "模拟复制完成"
    exit 0
else
    echo "错误: 源路径不存在: $SOURCE"
    exit 1
fi