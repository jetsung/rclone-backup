#!/usr/bin/env bash

# DEBUG 支持
if [[ -n "${DEBUG:-}" ]]; then
    set -eux
else
    set -euo pipefail
fi

echo "=== Rclone 定时备份服务启动 ==="

# 检查是否需要初始化 rclone 配置
if [ ! -f "$RCLONE_CONFIG" ]; then
    echo "检测到 rclone 配置文件不存在，启动初始化模式..."
    echo "请使用以下命令进入容器进行配置："
    echo "docker exec -it <container_name> /app/scripts/init-rclone.sh"
    echo ""
    echo "或者挂载现有的 rclone.conf 文件到 /config/rclone/rclone.conf"
    echo ""
    echo "配置完成后，重启容器以启动定时备份服务"
    
    # 保持容器运行，等待用户配置
    while [ ! -f "$RCLONE_CONFIG" ]; do
        sleep 30
        echo "等待 rclone 配置文件..."
    done
fi

# 检查备份配置文件
if [ ! -f "$BACKUP_CONFIG" ]; then
    echo "创建默认备份配置文件..."
    /app/scripts/create-default-config.sh
fi

# 设置定时任务
#echo "设置定时备份和同步任务..."
/app/scripts/setup-cron.sh

# 启动 cron 服务
echo "启动 cron 服务..."
crond -f -d 8