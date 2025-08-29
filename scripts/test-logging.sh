#!/usr/bin/env bash

# DEBUG 支持
if [[ -n "${DEBUG:-}" ]]; then
    set -eux
else
    set -euo pipefail
fi

# 测试日志功能的脚本

echo "测试日志功能..."

# 设置环境变量（模拟容器环境）
export BACKUP_LOG_DIR="${BACKUP_LOG_DIR:-/var/log/backup}"
export BACKUP_CONFIG="${BACKUP_CONFIG:-/app/config/config.json}"

# 确保日志目录存在
mkdir -p "$BACKUP_LOG_DIR"

# 创建测试日志文件
BACKUP_LOG_FILE="${BACKUP_LOG_DIR}/backup.log"
SYNC_LOG_FILE="${BACKUP_LOG_DIR}/sync.log"
CRON_LOG_FILE="${BACKUP_LOG_DIR}/cron.log"

# 写入测试日志
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$TIMESTAMP] 测试备份日志写入" >> "$BACKUP_LOG_FILE"
echo "[$TIMESTAMP] 测试同步日志写入" >> "$SYNC_LOG_FILE"
echo "[$TIMESTAMP] 测试 cron 日志写入" >> "$CRON_LOG_FILE"

echo "日志文件创建完成:"
echo "- 备份日志: $BACKUP_LOG_FILE"
echo "- 同步日志: $SYNC_LOG_FILE"
echo "- Cron 日志: $CRON_LOG_FILE"

echo ""
echo "日志内容预览:"
echo "=== 备份日志 ==="
cat "$BACKUP_LOG_FILE" 2>/dev/null || echo "备份日志文件不存在"

echo ""
echo "=== 同步日志 ==="
cat "$SYNC_LOG_FILE" 2>/dev/null || echo "同步日志文件不存在"

echo ""
echo "=== Cron 日志 ==="
cat "$CRON_LOG_FILE" 2>/dev/null || echo "Cron 日志文件不存在"

echo ""
echo "测试完成！"