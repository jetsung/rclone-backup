#!/bin/bash

# 日志轮转脚本
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$TIMESTAMP] 开始日志轮转..."

# 从配置文件获取日志设置
if [ -f "$BACKUP_CONFIG" ]; then
    max_log_size=$(jq -r '.global_options.max_log_size // "10M"' "$BACKUP_CONFIG")
    max_log_files=$(jq -r '.global_options.max_log_files // 5' "$BACKUP_CONFIG")
    log_file=$(jq -r '.global_options.log_file // "/var/log/backup/backup.log"' "$BACKUP_CONFIG")
else
    max_log_size="10M"
    max_log_files=5
    log_file="/var/log/backup/backup.log"
fi

# 转换大小单位为字节
case ${max_log_size: -1} in
    M|m) max_size_bytes=$((${max_log_size%?} * 1024 * 1024)) ;;
    K|k) max_size_bytes=$((${max_log_size%?} * 1024)) ;;
    G|g) max_size_bytes=$((${max_log_size%?} * 1024 * 1024 * 1024)) ;;
    *) max_size_bytes=$max_log_size ;;
esac

# 检查主日志文件大小
if [ -f "$log_file" ]; then
    current_size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo 0)
    
    if [ "$current_size" -gt "$max_size_bytes" ]; then
        echo "[$TIMESTAMP] 日志文件超过大小限制，开始轮转..."
        
        # 轮转现有的日志文件
        for i in $(seq $((max_log_files - 1)) -1 1); do
            if [ -f "${log_file}.$i" ]; then
                mv "${log_file}.$i" "${log_file}.$((i + 1))"
            fi
        done
        
        # 移动当前日志文件
        mv "$log_file" "${log_file}.1"
        
        # 创建新的日志文件
        touch "$log_file"
        
        # 删除超过保留数量的旧日志文件
        for i in $(seq $((max_log_files + 1)) 20); do
            if [ -f "${log_file}.$i" ]; then
                rm -f "${log_file}.$i"
            fi
        done
        
        echo "[$TIMESTAMP] 日志轮转完成"
    else
        echo "[$TIMESTAMP] 日志文件大小正常，无需轮转"
    fi
fi

# 清理超过7天的 cron 日志
find "$BACKUP_LOG_DIR" -name "cron.log.*" -mtime +7 -delete 2>/dev/null || true

echo "[$TIMESTAMP] 日志轮转检查完成"