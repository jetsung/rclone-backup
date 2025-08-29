#!/usr/bin/env bash

# DEBUG 支持
if [[ -n "${DEBUG:-}" ]]; then
    set -eux
else
    set -euo pipefail
fi

# 清理压缩文件的 post-backup hook 脚本

# 从环境变量获取信息
JOB_NAME="${BACKUP_JOB_NAME}"
LOG_FILE="${BACKUP_LOG_FILE}"

# 日志函数
log_hook_message() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [HOOK] $message" | tee -a "$LOG_FILE"
}

log_hook_message "开始执行清理 hook: $JOB_NAME"

# 查找并执行清理脚本
CLEANUP_SCRIPT="/tmp/backup-compress/cleanup.sh"
if [ -f "$CLEANUP_SCRIPT" ]; then
    log_hook_message "执行清理脚本: $CLEANUP_SCRIPT"
    source "$CLEANUP_SCRIPT"
else
    log_hook_message "未找到清理脚本，跳过清理"
fi

log_hook_message "清理 hook 执行完成"