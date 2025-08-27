FROM rclone/rclone:latest

# 安装必要的工具
RUN apk add --no-cache \
    bash \
    coreutils \
    dcron \
    jq \
    curl

# 创建工作目录
WORKDIR /app

# 复制脚本文件
COPY scripts/ /app/scripts/
COPY config/ /app/config/

# 设置脚本权限
RUN chmod +x /app/scripts/*.sh

# 创建必要的目录
RUN mkdir -p /config/rclone \
    /data/backup \
    /var/log/backup \
    /etc/crontabs

# 设置环境变量
ENV RCLONE_CONFIG=/config/rclone/rclone.conf
ENV BACKUP_LOG_DIR=/var/log/backup
ENV BACKUP_CONFIG=/app/config/config.json

# 启动脚本
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]