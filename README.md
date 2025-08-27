# Rclone 定时备份服务

基于 rclone 的 Docker 定时备份解决方案，支持多目标备份和灵活的配置管理。

## 功能特性

- 🚀 基于 rclone 的强大云存储支持
- ⏰ 灵活的 cron 定时任务配置
- 🎯 支持多目标同时备份
- 📥 支持定时从云端同步数据到本地
- 📝 详细的日志记录和轮转
- 🔧 简单的配置管理
- 🐳 完全容器化部署

## 快速开始

- 使用项目提供的 Docker 镜像

    > **版本：** `latest`, `dev`(GHCR only), <`TAG`>

    | Registry                                                                                   | Image                                                  |
    | ------------------------------------------------------------------------------------------ | ------------------------------------------------------ |
    | [**Docker Hub**](https://hub.docker.com/r/jetsung/rclone-backup/)                                | `jetsung/rclone-backup`                                    |
    | [**GitHub Container Registry**](https://github.com/jetsung/rclone-backup/pkgs/container/rclone-backup) | `ghcr.io/jetsung/rclone-backup`                            |
    | **Tencent Cloud Container Registry（SG）**                                                       | `sgccr.ccs.tencentyun.com/jetsung/rclone-backup`             |
    | **Aliyun Container Registry（GZ）**                                                              | `registry.cn-guangzhou.aliyuncs.com/jetsung/rclone-backup` |

### 1. 启动服务

```bash
# 克隆或创建项目目录
mkdir rclone-backup && cd rclone-backup

# 启动容器
docker compose up -d
```

### 2. 初始化 rclone 配置

首次运行时需要配置 rclone：

```bash
# 进入容器进行配置
docker exec -it rclone-backup /app/scripts/init-rclone.sh

# 或者直接进入容器
docker exec -it rclone-backup bash
rclone config
```

按照 rclone 的配置向导设置您的云存储服务（Google Drive、OneDrive、AWS S3 等）。

### 3. 配置同步任务（可选）

如果需要定时从云端同步数据到本地，编辑 `config/config.json` 文件，启用 `sync_jobs` 中的任务：

```bash
# 查看同步配置示例
docker exec rclone-backup /app/scripts/create-default-sync-config.sh
```

### 4. 重启服务

配置完成后重启容器以启动定时任务：

```bash
docker restart rclone-backup
```

## 配置说明

### 配置文件

编辑 `config/config.json` 来配置您的备份和同步任务：

```json
{
  "backup_jobs": [
    {
      "name": "documents_backup",
      "enabled": true,
      "source_path": "/data/documents",
      "targets": [
        {
          "remote": "gdrive",
          "path": "backup/documents",
          "enabled": true
        }
      ],
      "schedule": "0 2 * * *",
      "options": [
        "--progress",
        "--transfers=4",
        "--checkers=8"
      ]
    }
  ],
  "sync_jobs": [
    {
      "name": "documents_sync",
      "enabled": true,
      "destination_path": "/data/synced/documents",
      "sources": [
        {
          "remote": "gdrive",
          "path": "shared/documents",
          "enabled": true
        }
      ],
      "schedule": "0 1 * * *",
      "sync_mode": "copy",
      "options": [
        "--progress",
        "--transfers=4",
        "--checkers=8"
      ]
    }
  ]
}
```

### 配置参数说明

#### 备份任务 (backup_jobs)
- `name`: 备份任务名称
- `enabled`: 是否启用此任务
- `source_path`: 源目录路径
- `targets`: 备份目标列表
  - `remote`: rclone 配置的远程名称
  - `path`: 远程路径
  - `enabled`: 是否启用此目标
- `schedule`: cron 表达式 (分 时 日 月 周)
- `options`: rclone 命令选项

#### 同步任务 (sync_jobs)
- `name`: 同步任务名称
- `enabled`: 是否启用此任务
- `destination_path`: 本地目标目录路径
- `sources`: 同步源列表
  - `remote`: rclone 配置的远程名称
  - `path`: 远程路径
  - `enabled`: 是否启用此源
- `schedule`: cron 表达式 (分 时 日 月 周)
- `sync_mode`: 同步模式
  - `copy`: 只复制新文件和更新的文件 (推荐)
  - `sync`: 完全同步，会删除目标中不存在于源的文件
- `options`: rclone 命令选项

### 目录结构

```
.
├── docker/
│   └── Dockerfile
├── scripts/
│   ├── init-rclone.sh              # rclone 初始化脚本
│   ├── backup-job.sh               # 备份执行脚本
│   ├── sync-job.sh                 # 同步执行脚本
│   ├── create-default-config.sh    # 创建默认备份配置
│   ├── create-default-sync-config.sh # 创建默认同步配置
│   ├── setup-cron.sh               # 定时任务设置
│   ├── rotate-logs.sh              # 日志轮转脚本
│   └── test-logging.sh             # 测试日志功能
├── config/
│   └── config.json                 # 备份和同步配置文件
├── data/
│   ├── rclone/                    # rclone 配置目录
│   ├── backup/                    # 备份源目录
│   ├── synced/                    # 同步数据目录
│   └── logs/                      # 日志目录
├── docker-compose.yml
├── docker-bake.hcl
├── entrypoint.sh
└── README.md
```

## 使用示例

### 常用 cron 表达式

- `0 2 * * *` - 每天凌晨2点
- `0 3 * * 0` - 每周日凌晨3点
- `0 1 1 * *` - 每月1号凌晨1点
- `*/30 * * * *` - 每30分钟

### 查看日志

```bash
# 测试日志功能（首次使用建议运行）
docker exec rclone-backup /app/scripts/test-logging.sh

# 查看备份日志
docker exec rclone-backup tail -f /var/log/backup/backup.log

# 查看同步日志
docker exec rclone-backup tail -f /var/log/backup/sync.log

# 查看 cron 日志
docker exec rclone-backup tail -f /var/log/backup/cron.log

# 查看容器日志
docker logs -f rclone-backup

# 查看所有日志文件
docker exec rclone-backup ls -la /var/log/backup/
```

### 手动执行任务

```bash
# 执行特定的备份任务
docker exec rclone-backup /app/scripts/backup-job.sh "documents_backup"

# 执行特定的同步任务
docker exec rclone-backup /app/scripts/sync-job.sh "documents_sync"
```

### 管理 rclone 配置

```bash
# 查看已配置的远程
docker exec rclone-backup rclone listremotes

# 测试连接
docker exec rclone-backup rclone lsd gdrive:

# 重新配置
docker exec rclone-backup rclone config
```

## 故障排除

### 常见问题

1. **容器启动后立即退出**
   - 检查 rclone 配置是否正确
   - 查看容器日志: `docker logs rclone-backup`

2. **备份任务不执行**
   - 检查 cron 配置: `docker exec rclone-backup cat /etc/crontabs/root`
   - 查看 cron 日志确认任务是否被触发

3. **备份失败**
   - 检查源目录是否存在且有读取权限
   - 验证 rclone 远程配置是否正确
   - 查看详细的备份日志

### 调试模式

```bash
# 进入容器调试
docker exec -it rclone-backup bash

# 手动测试 rclone 命令
rclone copy /data/backup gdrive:backup/test --dry-run -v
```

## 安全建议

- 定期备份 rclone 配置文件
- 使用强密码保护云存储账户
- 定期检查备份完整性
- 监控日志文件大小和磁盘空间

## 许可证

Apache License 2.0

## 仓库镜像

- https://git.jetsung.com/jetsung/rclone-backup
- https://framagit.org/jetsung/rclone-backup
- https://gitcode.com/jetsung/rclone-backup
- https://github.com/jetsung/rclone-backup
