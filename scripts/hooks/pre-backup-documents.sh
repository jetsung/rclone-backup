#!/usr/bin/env bash

# DEBUG 支持
if [[ -n "${DEBUG:-}" ]]; then
    set -eux
else
    set -euo pipefail
fi

# 文档备份前的示例 hook 脚本
# 可以在这里添加文档整理、索引生成等操作

# 从环境变量获取信息
JOB_NAME="${BACKUP_JOB_NAME}"
SOURCE_PATH="${BACKUP_SOURCE_PATH}"
LOG_FILE="${BACKUP_LOG_FILE}"

# 日志函数
log_hook_message() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [HOOK] $message" | tee -a "$LOG_FILE"
}

log_hook_message "开始执行文档备份前处理: $JOB_NAME"
log_hook_message "处理路径: $SOURCE_PATH"

# 示例：生成文件清单
if [ -d "$SOURCE_PATH" ]; then
    DATE_FORMATTED=$(date '+%Y%m%d')
    MANIFEST_FILE="$SOURCE_PATH/.backup_manifest_${DATE_FORMATTED}.txt"
    log_hook_message "生成文件清单: $MANIFEST_FILE"
    
    find "$SOURCE_PATH" -type f -exec ls -lh {} \; > "$MANIFEST_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        log_hook_message "文件清单生成成功"
    else
        log_hook_message "警告: 文件清单生成失败"
    fi
fi

# 示例：检查磁盘空间
AVAILABLE_SPACE=$(df -h "$SOURCE_PATH" | awk 'NR==2 {print $4}')
log_hook_message "可用磁盘空间: $AVAILABLE_SPACE"

log_hook_message "文档备份前处理完成"