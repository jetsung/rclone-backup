# Hook 配置示例

本文档提供了各种 Hook 配置的实用示例。

## 基础压缩备份

将目录压缩为 tar.xz 格式后备份：

```json
{
  "name": "compressed_documents",
  "enabled": true,
  "source_path": "/data/documents",
  "backup_mode": "copy",
  "targets": [
    {
      "remote": "gdrive",
      "path": "backup/documents-compressed",
      "enabled": true
    }
  ],
  "schedule": "0 2 * * *",
  "hooks": {
    "pre_backup": {
      "enabled": true,
      "script": "/app/hooks/compress-backup.sh",
      "timeout": 1800,
      "fail_on_error": true,
      "description": "压缩文档目录"
    },
    "post_backup": {
      "enabled": true,
      "script": "/app/hooks/cleanup-compressed.sh",
      "timeout": 60,
      "fail_on_error": false,
      "description": "清理临时压缩文件"
    }
  }
}
```

### 环境变量配置

可以通过环境变量自定义压缩行为：

```bash
# 在 docker-compose.yml 中添加
environment:
  - COMPRESS_FORMAT=gz          # 使用 gzip 压缩
  - COMPRESS_LEVEL=9            # 最高压缩级别
  - EXCLUDE_PATTERNS=*.tmp *.log .git
```

## 数据库备份

### MySQL 数据库备份

```json
{
  "name": "mysql_backup",
  "enabled": true,
  "source_path": "/tmp/mysql-backup",
  "backup_mode": "copy",
  "targets": [
    {
      "remote": "s3",
      "path": "database-backups/mysql",
      "enabled": true
    }
  ],
  "schedule": "0 3 * * *",
  "hooks": {
    "pre_backup": {
      "enabled": true,
      "script": "/app/hooks/dump-database.sh",
      "timeout": 3600,
      "fail_on_error": true,
      "description": "导出 MySQL 数据库"
    },
    "post_backup": {
      "enabled": true,
      "script": "/tmp/mysql-backup/cleanup.sh",
      "timeout": 60,
      "fail_on_error": false,
      "description": "清理数据库导出文件"
    }
  }
}
```

### 环境变量配置

```bash
# MySQL 配置
environment:
  - DB_TYPE=mysql
  - DB_HOST=mysql-server
  - DB_PORT=3306
  - DB_USER=backup_user
  - DB_PASSWORD=backup_password
  - DB_NAME=my_database          # 留空备份所有数据库
  - COMPRESS_DB_BACKUP=true     # 压缩备份文件
```

### PostgreSQL 数据库备份

```bash
# PostgreSQL 配置
environment:
  - DB_TYPE=postgresql
  - DB_HOST=postgres-server
  - DB_PORT=5432
  - DB_USER=backup_user
  - DB_PASSWORD=backup_password
  - DB_NAME=my_database          # 留空备份所有数据库
```

## 网站备份

备份网站文件和数据库：

```json
{
  "name": "website_backup",
  "enabled": true,
  "source_path": "/tmp/website-backup",
  "backup_mode": "copy",
  "targets": [
    {
      "remote": "gdrive",
      "path": "backup/website",
      "enabled": true
    },
    {
      "remote": "s3",
      "path": "website-backups",
      "enabled": true
    }
  ],
  "schedule": "0 4 * * *",
  "hooks": {
    "pre_backup": {
      "enabled": true,
      "script": "/app/hooks/backup-website.sh",
      "timeout": 3600,
      "fail_on_error": true,
      "description": "备份网站文件和数据库"
    },
    "post_backup": {
      "enabled": true,
      "script": "/tmp/website-backup/cleanup.sh",
      "timeout": 120,
      "fail_on_error": false,
      "description": "清理临时备份文件"
    }
  }
}
```

## 自定义通知 Hook

备份完成后发送通知：

```bash
#!/bin/bash
# /app/hooks/send-notification.sh

JOB_NAME="${BACKUP_JOB_NAME}"
LOG_FILE="${BACKUP_LOG_FILE}"

log_hook_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [HOOK] $1" | tee -a "$LOG_FILE"
}

# 发送邮件通知（需要配置 sendmail 或 SMTP）
if command -v mail >/dev/null 2>&1; then
    echo "备份任务 '$JOB_NAME' 已完成于 $(date)" | mail -s "备份完成通知" admin@example.com
    log_hook_message "邮件通知已发送"
fi

# 发送 Webhook 通知
if [ -n "$WEBHOOK_URL" ]; then
    curl -X POST "$WEBHOOK_URL" \
         -H "Content-Type: application/json" \
         -d "{\"text\":\"备份任务 '$JOB_NAME' 已完成\"}" \
         2>&1 | tee -a "$LOG_FILE"
    log_hook_message "Webhook 通知已发送"
fi

# 发送 Slack 通知
if [ -n "$SLACK_WEBHOOK_URL" ]; then
    curl -X POST "$SLACK_WEBHOOK_URL" \
         -H "Content-Type: application/json" \
         -d "{\"text\":\"✅ 备份任务 \`$JOB_NAME\` 已完成\"}" \
         2>&1 | tee -a "$LOG_FILE"
    log_hook_message "Slack 通知已发送"
fi
```

## Docker 容器备份

备份 Docker 容器数据：

```bash
#!/bin/bash
# /app/hooks/backup-docker-volumes.sh

JOB_NAME="${BACKUP_JOB_NAME}"
SOURCE_PATH="${BACKUP_SOURCE_PATH}"
LOG_FILE="${BACKUP_LOG_FILE}"

log_hook_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [HOOK] $1" | tee -a "$LOG_FILE"
}

# 停止容器（可选）
if [ "${STOP_CONTAINERS:-false}" = "true" ]; then
    log_hook_message "停止 Docker 容器: $CONTAINER_NAMES"
    docker stop $CONTAINER_NAMES
fi

# 备份 Docker 卷
for volume in $DOCKER_VOLUMES; do
    log_hook_message "备份 Docker 卷: $volume"
    docker run --rm -v "$volume:/source" -v "$SOURCE_PATH:/backup" \
        alpine tar czf "/backup/${volume}_$(date +%Y%m%d_%H%M%S).tar.gz" -C /source .
done

# 重启容器（如果之前停止了）
if [ "${STOP_CONTAINERS:-false}" = "true" ]; then
    log_hook_message "重启 Docker 容器: $CONTAINER_NAMES"
    docker start $CONTAINER_NAMES
fi
```

## 环境变量参考

### 通用环境变量

- `BACKUP_JOB_NAME`: 当前备份任务名称
- `BACKUP_SOURCE_PATH`: 备份源路径
- `BACKUP_TIMESTAMP`: 备份开始时间戳
- `BACKUP_LOG_FILE`: 备份日志文件路径

### 压缩相关

- `COMPRESS_FORMAT`: 压缩格式 (xz, gz, bz2, zip)
- `COMPRESS_LEVEL`: 压缩级别 (1-9)
- `EXCLUDE_PATTERNS`: 排除模式

### 数据库相关

- `DB_TYPE`: 数据库类型 (mysql, postgresql)
- `DB_HOST`: 数据库主机
- `DB_PORT`: 数据库端口
- `DB_USER`: 数据库用户
- `DB_PASSWORD`: 数据库密码
- `DB_NAME`: 数据库名称
- `COMPRESS_DB_BACKUP`: 是否压缩数据库备份

### 通知相关

- `WEBHOOK_URL`: 通用 Webhook URL
- `SLACK_WEBHOOK_URL`: Slack Webhook URL
- `EMAIL_TO`: 邮件接收地址

### Docker 相关

- `DOCKER_VOLUMES`: 要备份的 Docker 卷列表
- `CONTAINER_NAMES`: 容器名称列表
- `STOP_CONTAINERS`: 是否在备份时停止容器