#!/usr/bin/env bash

# 测试 hook 与主脚本通信的修复

echo "=== 测试 Hook 通信修复 ==="

# 创建测试目录
mkdir -p /tmp/test-source
mkdir -p /tmp/test-logs

# 创建测试文件
echo "测试文件1" > /tmp/test-source/file1.txt
echo "测试文件2" > /tmp/test-source/file2.txt

# 创建简化的测试 hook 脚本
cat > /tmp/test-compress-hook.sh << 'EOF'
#!/bin/bash
echo "测试 hook 开始执行"
echo "原始源路径: $BACKUP_SOURCE_PATH"
echo "Hook 输出文件: $BACKUP_HOOK_OUTPUT_FILE"

# 模拟压缩操作
COMPRESS_DIR="/tmp/test-compressed"
mkdir -p "$COMPRESS_DIR"
tar -czf "$COMPRESS_DIR/test_backup.tar.gz" -C "$(dirname "$BACKUP_SOURCE_PATH")" "$(basename "$BACKUP_SOURCE_PATH")"

# 通知主脚本使用新路径
if [ -n "${BACKUP_HOOK_OUTPUT_FILE:-}" ]; then
    echo "$COMPRESS_DIR" > "$BACKUP_HOOK_OUTPUT_FILE"
    echo "已写入新路径到: $BACKUP_HOOK_OUTPUT_FILE"
    echo "新路径内容: $COMPRESS_DIR"
else
    echo "错误: BACKUP_HOOK_OUTPUT_FILE 未设置"
fi
EOF

chmod +x /tmp/test-compress-hook.sh

# 创建测试配置
cat > /tmp/test-hook-config.json << 'EOF'
{
  "backup_jobs": [
    {
      "name": "test_hook_communication",
      "enabled": true,
      "source_path": "/tmp/test-source",
      "backup_mode": "copy",
      "targets": [
        {
          "remote": "local",
          "path": "/tmp/test-backup-target",
          "enabled": true
        }
      ],
      "options": [
        "--progress"
      ],
      "hooks": {
        "pre_backup": {
          "enabled": true,
          "script": "/tmp/test-compress-hook.sh",
          "timeout": 300,
          "fail_on_error": true,
          "description": "测试 hook 通信"
        }
      }
    }
  ]
}
EOF

echo "测试环境准备完成"
echo ""
echo "测试文件:"
echo "- 源目录: /tmp/test-source"
echo "- Hook 脚本: /tmp/test-compress-hook.sh"
echo "- 配置文件: /tmp/test-hook-config.json"
echo ""
echo "要运行测试，请执行:"
echo "export BACKUP_CONFIG=/tmp/test-hook-config.json"
echo "export BACKUP_LOG_DIR=/tmp/test-logs"
echo "bash /app/scripts/backup-job.sh test_hook_communication"
echo ""
echo "预期结果:"
echo "1. Hook 脚本应该创建压缩包到 /tmp/test-compressed/"
echo "2. 主脚本应该备份压缩包而不是原始源目录"
echo "3. 日志中应该显示 'Hook 更新了备份源路径为: /tmp/test-compressed'"