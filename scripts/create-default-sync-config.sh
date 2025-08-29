#!/usr/bin/env bash

# DEBUG 支持
if [[ -n "${DEBUG:-}" ]]; then
    set -eux
else
    set -euo pipefail
fi

# 创建默认的同步配置示例

echo "创建默认同步配置示例..."

# 检查配置文件是否存在
if [ ! -f "/app/config/config.json" ]; then
    echo "错误: 配置文件不存在"
    exit 1
fi

# 创建示例同步任务配置
cat > /tmp/sync_example.json << 'EOF'
{
  "name": "example_sync",
  "enabled": false,
  "destination_path": "/data/synced/example",
  "sources": [
    {
      "remote": "your_remote_name",
      "path": "path/to/remote/folder",
      "enabled": true
    }
  ],
  "schedule": "0 6 * * *",
  "sync_mode": "copy",
  "options": [
    "--progress",
    "--transfers=2",
    "--checkers=4",
    "--exclude=*.tmp",
    "--exclude=*.log"
  ]
}
EOF

echo "示例同步任务配置已创建在 /tmp/sync_example.json"
echo "请根据您的需求修改配置文件 /app/config/config.json"
echo ""
echo "同步任务配置说明:"
echo "- name: 任务名称"
echo "- enabled: 设置为 true 启用任务"
echo "- destination_path: 本地存储路径"
echo "- sources: 远程数据源列表"
echo "- schedule: cron 表达式"
echo "- sync_mode: copy (增量) 或 sync (完全同步)"
echo "- options: rclone 选项"