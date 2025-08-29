#!/usr/bin/env bash

# DEBUG 支持
if [[ -n "${DEBUG:-}" ]]; then
    set -eux
else
    set -euo pipefail
fi

echo "设置定时备份和同步任务..."

# 清空现有的 crontab
> /etc/crontabs/root

# 从配置文件读取备份任务
if [ -f "$BACKUP_CONFIG" ]; then
    # 使用 jq 解析 JSON 配置 - 备份任务
    backup_jobs=$(jq -r '.backup_jobs[] | select(.enabled == true) | @base64' "$BACKUP_CONFIG")
    
    for job in $backup_jobs; do
        # 解码 base64
        job_data=$(echo "$job" | base64 -d)
        
        # 提取任务信息
        name=$(echo "$job_data" | jq -r '.name')
        schedule=$(echo "$job_data" | jq -r '.schedule')
        
        # 添加到 crontab
        echo "$schedule /app/scripts/backup-job.sh '$name' >> /var/log/backup/cron.log 2>&1" >> /etc/crontabs/root
        
        echo "已添加备份任务: $name ($schedule)"
    done
    
    # 使用 jq 解析 JSON 配置 - 同步任务
    sync_jobs=$(jq -r '.sync_jobs[]? | select(.enabled == true) | @base64' "$BACKUP_CONFIG")
    
    for job in $sync_jobs; do
        # 解码 base64
        job_data=$(echo "$job" | base64 -d)
        
        # 提取任务信息
        name=$(echo "$job_data" | jq -r '.name')
        schedule=$(echo "$job_data" | jq -r '.schedule')
        
        # 添加到 crontab
        echo "$schedule /app/scripts/sync-job.sh '$name' >> /var/log/backup/cron.log 2>&1" >> /etc/crontabs/root
        
        echo "已添加同步任务: $name ($schedule)"
    done
else
    echo "警告: 备份配置文件不存在"
fi

# 添加日志轮转任务 (每天凌晨1点)
echo "0 1 * * * /app/scripts/rotate-logs.sh >> /var/log/backup/cron.log 2>&1" >> /etc/crontabs/root

echo "定时任务设置完成"
echo "当前 crontab 内容:"
cat /etc/crontabs/root