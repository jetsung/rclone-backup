#!/usr/bin/env bash

# DEBUG 支持
if [[ -n "${DEBUG:-}" ]]; then
    set -eux
else
    set -euo pipefail
fi

echo "=== Rclone 配置初始化 ==="

# 确保配置目录存在
mkdir -p /config/rclone

echo "开始 rclone 配置向导..."
echo "请按照提示配置您的云存储服务"
echo ""

# 启动 rclone 配置
rclone config

echo ""
echo "配置完成！"
echo "配置文件已保存到: $RCLONE_CONFIG"
echo ""
echo "请重启容器以启动定时备份服务："
echo "docker restart <container_name>"