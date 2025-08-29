#!/usr/bin/env bash

# DEBUG 支持
if [[ -n "${DEBUG:-}" ]]; then
    set -eux
else
    set -euo pipefail
fi

# 文档备份后的示例 hook 脚本
# 可以在这里添加通知、清理等操作

# 从环境变量获取信息
JOB_NAME="${BACKUP_JOB_NAME}"
SOURCE_PATH="${BACKUP_SOURCE_PATH}"
LOG_FILE="${BACKUP_LOG_FILE}"

# 日志函数
log_hook_message() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [HOOK] $message" | tee -a "$LOG_FILE"
}

log_hook_message "开始执行文档备份后处理: $JOB_NAME"

# 示例：清理临时文件
if [ -d "$SOURCE_PATH" ]; then
    log_hook_message "清理备份清单文件"
    find "$SOURCE_PATH" -name ".backup_manifest_*.txt" -mtime +7 -delete 2>/dev/null
fi

# 示例：发送通知（这里只是记录日志，实际可以集成邮件、webhook等）
log_hook_message "备份完成通知: 文档备份任务 '$JOB_NAME' 已完成"

log_hook_message "文档备份后处理完成"