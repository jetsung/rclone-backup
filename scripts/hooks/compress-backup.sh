#!/usr/bin/env bash

# DEBUG 支持
if [[ -n "${DEBUG:-}" ]]; then
    set -eux
else
    set -euo pipefail
fi

# 压缩备份目录的示例 hook 脚本
# 支持多种压缩格式：tar.xz, tar.gz, tar.bz2, zip

# 从环境变量获取信息
JOB_NAME="${BACKUP_JOB_NAME}"
SOURCE_PATH="${BACKUP_SOURCE_PATH}"
LOG_FILE="${BACKUP_LOG_FILE}"

# 配置选项
COMPRESS_FORMAT="${COMPRESS_FORMAT:-xz}"  # 默认使用 xz 压缩
COMPRESS_LEVEL="${COMPRESS_LEVEL:-6}"     # 压缩级别 (1-9)
EXCLUDE_PATTERNS="${EXCLUDE_PATTERNS:-*.tmp *.log .DS_Store}"  # 排除模式

# 日志函数
log_hook_message() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [HOOK] $message" | tee -a "$LOG_FILE"
}

log_hook_message "开始执行压缩 hook: $JOB_NAME"
log_hook_message "源路径: $SOURCE_PATH"
log_hook_message "压缩格式: $COMPRESS_FORMAT"
log_hook_message "压缩级别: $COMPRESS_LEVEL"

# 检查源路径
if [ ! -d "$SOURCE_PATH" ]; then
    log_hook_message "错误: 源路径不存在: $SOURCE_PATH"
    exit 1
fi

# 创建压缩文件的目标目录
COMPRESS_DIR="/tmp/backup-compress"
mkdir -p "$COMPRESS_DIR"

# 清理旧的压缩文件（保持目录干净）
log_hook_message "清理旧的压缩文件..."
find "$COMPRESS_DIR" -name "${JOB_NAME}_*.tar.*" -o -name "${JOB_NAME}_*.zip" | while read -r old_file; do
    if [ -f "$old_file" ]; then
        log_hook_message "删除旧文件: $old_file"
        rm -f "$old_file"
    fi
done

# 根据压缩格式生成文件名和命令（使用日期格式）
DATE_FORMATTED=$(date '+%Y%m%d')
case "$COMPRESS_FORMAT" in
    "xz")
        ARCHIVE_NAME="${JOB_NAME}_${DATE_FORMATTED}.tar.xz"
        TAR_OPTIONS="-cJf"
        ;;
    "gz"|"gzip")
        ARCHIVE_NAME="${JOB_NAME}_${DATE_FORMATTED}.tar.gz"
        TAR_OPTIONS="-czf"
        ;;
    "bz2"|"bzip2")
        ARCHIVE_NAME="${JOB_NAME}_${DATE_FORMATTED}.tar.bz2"
        TAR_OPTIONS="-cjf"
        ;;
    "zip")
        ARCHIVE_NAME="${JOB_NAME}_${DATE_FORMATTED}.zip"
        ;;
    *)
        log_hook_message "错误: 不支持的压缩格式: $COMPRESS_FORMAT"
        exit 1
        ;;
esac

ARCHIVE_PATH="$COMPRESS_DIR/$ARCHIVE_NAME"
log_hook_message "开始压缩到: $ARCHIVE_PATH"

# 构建排除参数
EXCLUDE_ARGS=""
for pattern in $EXCLUDE_PATTERNS; do
    EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude=$pattern"
done

# 执行压缩
START_TIME=$(date +%s)

if [ "$COMPRESS_FORMAT" = "zip" ]; then
    # 使用 zip 压缩
    cd "$(dirname "$SOURCE_PATH")"
    if zip -r -$COMPRESS_LEVEL "$ARCHIVE_PATH" "$(basename "$SOURCE_PATH")" -x $EXCLUDE_PATTERNS 2>&1 | tee -a "$LOG_FILE"; then
        COMPRESS_SUCCESS=true
    else
        COMPRESS_SUCCESS=false
    fi
else
    # 使用 tar 压缩
    if tar $TAR_OPTIONS "$ARCHIVE_PATH" $EXCLUDE_ARGS -C "$(dirname "$SOURCE_PATH")" "$(basename "$SOURCE_PATH")" 2>&1 | tee -a "$LOG_FILE"; then
        COMPRESS_SUCCESS=true
    else
        COMPRESS_SUCCESS=false
    fi
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

if [ "$COMPRESS_SUCCESS" = "true" ]; then
    log_hook_message "压缩成功完成，耗时: ${DURATION}秒"
    
    # 显示压缩文件信息
    ARCHIVE_SIZE=$(du -h "$ARCHIVE_PATH" | cut -f1)
    ORIGINAL_SIZE=$(du -sh "$SOURCE_PATH" | cut -f1)
    log_hook_message "原始大小: $ORIGINAL_SIZE"
    log_hook_message "压缩后大小: $ARCHIVE_SIZE"
    
    # 计算压缩比
    ORIGINAL_BYTES=$(du -sb "$SOURCE_PATH" | cut -f1)
    ARCHIVE_BYTES=$(du -sb "$ARCHIVE_PATH" | cut -f1)
    if [ "$ORIGINAL_BYTES" -gt 0 ]; then
        RATIO=$(echo "scale=1; $ARCHIVE_BYTES * 100 / $ORIGINAL_BYTES" | bc 2>/dev/null || echo "N/A")
        log_hook_message "压缩比: ${RATIO}%"
    fi
    
    # 通过临时文件通知主脚本使用压缩后的目录
    if [ -n "${BACKUP_HOOK_OUTPUT_FILE:-}" ]; then
        echo "$COMPRESS_DIR" > "$BACKUP_HOOK_OUTPUT_FILE"
        log_hook_message "已通知主脚本更新备份源路径为: $COMPRESS_DIR"
    else
        log_hook_message "警告: 无法通知主脚本更新备份源路径"
    fi
    
    # 创建清理脚本供备份完成后使用（放在临时目录外避免被备份）
    CLEANUP_SCRIPT="/tmp/backup_cleanup_${JOB_NAME}_$$.sh"
    cat > "$CLEANUP_SCRIPT" << EOF
#!/bin/bash
log_hook_message() {
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] [CLEANUP] \$1" | tee -a "$LOG_FILE"
}
log_hook_message "开始清理临时压缩文件和目录"
log_hook_message "清理压缩文件: $ARCHIVE_PATH"
rm -f "$ARCHIVE_PATH"
log_hook_message "清理压缩目录: $COMPRESS_DIR"
rm -rf "$COMPRESS_DIR"
log_hook_message "清理脚本自身: $CLEANUP_SCRIPT"
rm -f "$CLEANUP_SCRIPT"
log_hook_message "临时文件清理完成"
EOF
    chmod +x "$CLEANUP_SCRIPT"
    
    # 将清理脚本路径写入环境变量供主脚本使用
    echo "$CLEANUP_SCRIPT" > "/tmp/backup_cleanup_path_${JOB_NAME}_$$"
    
else
    log_hook_message "错误: 压缩失败"
    exit 1
fi

log_hook_message "压缩 hook 执行完成"