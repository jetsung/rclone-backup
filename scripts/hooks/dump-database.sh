#!/usr/bin/env bash

# DEBUG 支持
if [[ -n "${DEBUG:-}" ]]; then
    set -eux
else
    set -euo pipefail
fi

# 数据库备份 hook 脚本示例
# 支持 MySQL/MariaDB 和 PostgreSQL

# 从环境变量获取信息
JOB_NAME="${BACKUP_JOB_NAME}"
SOURCE_PATH="${BACKUP_SOURCE_PATH}"
LOG_FILE="${BACKUP_LOG_FILE}"

# 数据库配置（可以通过环境变量覆盖）
DB_TYPE="${DB_TYPE:-mysql}"  # mysql 或 postgresql
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-root}"
DB_PASSWORD="${DB_PASSWORD:-}"
DB_NAME="${DB_NAME:-}"

# 日志函数
log_hook_message() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [HOOK] $message" | tee -a "$LOG_FILE"
}

log_hook_message "开始执行数据库备份 hook: $JOB_NAME"
log_hook_message "数据库类型: $DB_TYPE"
log_hook_message "数据库主机: $DB_HOST:$DB_PORT"

# 确保备份目录存在
mkdir -p "$SOURCE_PATH"

# 生成备份文件名（使用日期格式）
DATE_FORMATTED=$(date '+%Y%m%d')
BACKUP_FILE="$SOURCE_PATH/database_${DATE_FORMATTED}.sql"

case "$DB_TYPE" in
    "mysql"|"mariadb")
        log_hook_message "开始 MySQL/MariaDB 备份"
        
        # 构建 mysqldump 命令
        MYSQL_CMD="mysqldump -h$DB_HOST -P$DB_PORT -u$DB_USER"
        
        if [ -n "$DB_PASSWORD" ]; then
            MYSQL_CMD="$MYSQL_CMD -p$DB_PASSWORD"
        fi
        
        # 添加常用选项
        MYSQL_CMD="$MYSQL_CMD --single-transaction --routines --triggers --events"
        
        if [ -n "$DB_NAME" ]; then
            MYSQL_CMD="$MYSQL_CMD $DB_NAME"
        else
            MYSQL_CMD="$MYSQL_CMD --all-databases"
        fi
        
        # 执行备份
        if eval "$MYSQL_CMD" > "$BACKUP_FILE" 2>&1; then
            log_hook_message "MySQL/MariaDB 备份成功: $BACKUP_FILE"
        else
            log_hook_message "错误: MySQL/MariaDB 备份失败"
            exit 1
        fi
        ;;
        
    "postgresql"|"postgres")
        log_hook_message "开始 PostgreSQL 备份"
        
        # 设置 PostgreSQL 环境变量
        export PGHOST="$DB_HOST"
        export PGPORT="$DB_PORT"
        export PGUSER="$DB_USER"
        
        if [ -n "$DB_PASSWORD" ]; then
            export PGPASSWORD="$DB_PASSWORD"
        fi
        
        # 构建 pg_dump 命令
        if [ -n "$DB_NAME" ]; then
            PG_CMD="pg_dump --verbose --clean --no-owner --no-privileges $DB_NAME"
        else
            PG_CMD="pg_dumpall --verbose --clean"
        fi
        
        # 执行备份
        if eval "$PG_CMD" > "$BACKUP_FILE" 2>&1; then
            log_hook_message "PostgreSQL 备份成功: $BACKUP_FILE"
        else
            log_hook_message "错误: PostgreSQL 备份失败"
            exit 1
        fi
        ;;
        
    *)
        log_hook_message "错误: 不支持的数据库类型: $DB_TYPE"
        exit 1
        ;;
esac

# 显示备份文件信息
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
log_hook_message "备份文件大小: $BACKUP_SIZE"

# 压缩备份文件（可选）
if [ "${COMPRESS_DB_BACKUP:-true}" = "true" ]; then
    log_hook_message "压缩备份文件..."
    if gzip "$BACKUP_FILE"; then
        BACKUP_FILE="${BACKUP_FILE}.gz"
        COMPRESSED_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        log_hook_message "压缩完成，压缩后大小: $COMPRESSED_SIZE"
    else
        log_hook_message "警告: 压缩失败，使用未压缩的备份文件"
    fi
fi

# 创建清理脚本
cat > "$SOURCE_PATH/cleanup.sh" << EOF
#!/bin/bash
log_hook_message() {
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] [CLEANUP] \$1" | tee -a "$LOG_FILE"
}
log_hook_message "清理数据库备份文件: $BACKUP_FILE"
rm -f "$BACKUP_FILE"
# 清理超过7天的旧备份文件
find "$SOURCE_PATH" -name "database_*.sql*" -mtime +7 -delete 2>/dev/null
log_hook_message "数据库备份清理完成"
EOF
chmod +x "$SOURCE_PATH/cleanup.sh"

log_hook_message "数据库备份 hook 执行完成"