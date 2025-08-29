#!/usr/bin/env bash

# DEBUG 支持
if [[ -n "${DEBUG:-}" ]]; then
    set -eux
else
    set -euo pipefail
fi

# 创建默认备份配置文件
cat > "$BACKUP_CONFIG" << 'EOF'
{
  "backup_jobs": [
    {
      "name": "example_backup",
      "enabled": false,
      "source_path": "/data/backup",
      "targets": [
        {
          "remote": "remote1",
          "path": "backup/data",
          "enabled": true
        }
      ],
      "schedule": "0 2 * * *",
      "options": [
        "--progress",
        "--transfers=4",
        "--checkers=8",
        "--exclude=*.tmp",
        "--exclude=*.log"
      ]
    }
  ],
  "global_options": {
    "log_level": "INFO",
    "log_file": "/var/log/backup/backup.log",
    "max_log_size": "10M",
    "max_log_files": 5
  }
}
EOF

echo "默认备份配置文件已创建: $BACKUP_CONFIG"
echo "请根据需要修改配置文件"