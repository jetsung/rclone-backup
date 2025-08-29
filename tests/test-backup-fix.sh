#!/usr/bin/env bash

# 测试备份修复的脚本

echo "=== 测试备份脚本修复 ==="

# 设置测试环境变量
export BACKUP_CONFIG="/app/config/config.json"
export BACKUP_LOG_DIR="/tmp/test-logs"

# 创建测试目录和文件
mkdir -p /tmp/test-source
echo "测试文件内容" > /tmp/test-source/test.txt
echo "另一个测试文件" > /tmp/test-source/test2.txt

# 创建测试配置
cat > /tmp/test-config.json << 'EOF'
{
  "backup_jobs": [
    {
      "name": "test_backup",
      "enabled": true,
      "source_path": "/tmp/test-source",
      "backup_mode": "copy",
      "targets": [
        {
          "remote": "local",
          "path": "/tmp/test-backup",
          "enabled": true
        }
      ],
      "options": [
        "--progress"
      ],
      "hooks": {
        "pre_backup": {
          "enabled": true,
          "script": "/app/hooks/compress-backup.sh",
          "timeout": 300,
          "fail_on_error": true,
          "description": "测试压缩备份"
        }
      }
    }
  ]
}
EOF

# 设置测试配置路径
export BACKUP_CONFIG="/tmp/test-config.json"

echo "1. 测试 BACKUP_TIMESTAMP 参数使用"
echo "2. 测试 BACKUP_SOURCE_PATH 路径更新"
echo "3. 测试压缩后备份压缩包而非原路径"

echo ""
echo "测试环境已准备就绪。"
echo "源路径: /tmp/test-source"
echo "配置文件: /tmp/test-config.json"
echo ""
echo "要运行测试，请执行："
echo "bash /app/scripts/backup-job.sh test_backup"