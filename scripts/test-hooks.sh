#!/usr/bin/env bash

# DEBUG 支持
if [[ -n "${DEBUG:-}" ]]; then
    set -eux
else
    set -euo pipefail
fi

# Hook 功能测试脚本

# 设置测试环境
TEST_DIR="/tmp/hook-test"
TEST_SOURCE="$TEST_DIR/source"
TEST_CONFIG="$TEST_DIR/test-config.json"

# 日志函数
log_test() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [TEST] $1"
}

cleanup_test() {
    log_test "清理测试环境"
    rm -rf "$TEST_DIR"
}

# 捕获退出信号进行清理
trap cleanup_test EXIT

log_test "开始 Hook 功能测试"

# 创建测试目录和文件
log_test "创建测试环境"
mkdir -p "$TEST_SOURCE"
echo "测试文件内容 $(date)" > "$TEST_SOURCE/test.txt"
echo "另一个测试文件 $(date)" > "$TEST_SOURCE/test2.txt"
mkdir -p "$TEST_SOURCE/subdir"
echo "子目录文件 $(date)" > "$TEST_SOURCE/subdir/subfile.txt"

# 创建测试配置
cat > "$TEST_CONFIG" << 'EOF'
{
  "backup_jobs": [
    {
      "name": "hook_test",
      "enabled": true,
      "source_path": "/tmp/hook-test/source",
      "backup_mode": "copy",
      "targets": [
        {
          "remote": "local",
          "path": "/tmp/hook-test/backup",
          "enabled": true
        }
      ],
      "schedule": "* * * * *",
      "options": [
        "--progress"
      ],
      "hooks": {
        "pre_backup": {
          "enabled": true,
          "script": "/app/hooks/compress-backup.sh",
          "timeout": 300,
          "fail_on_error": true,
          "description": "测试压缩功能"
        },
        "post_backup": {
          "enabled": true,
          "script": "/app/hooks/cleanup-compressed.sh",
          "timeout": 60,
          "fail_on_error": false,
          "description": "测试清理功能"
        }
      }
    }
  ]
}
EOF

# 配置本地 rclone remote（用于测试）
log_test "配置测试用的 rclone remote"
mkdir -p "$TEST_DIR/backup"
rclone config create local local --config /tmp/rclone-test.conf

# 设置测试环境变量
export BACKUP_CONFIG="$TEST_CONFIG"
export BACKUP_LOG_DIR="$TEST_DIR/logs"
export RCLONE_CONFIG="/tmp/rclone-test.conf"
mkdir -p "$BACKUP_LOG_DIR"

# 测试 Hook 创建功能
log_test "测试 Hook 创建功能"
if /app/scripts/create-hook.sh pre-backup test-hook; then
    log_test "✓ Hook 创建功能正常"
else
    log_test "✗ Hook 创建功能失败"
fi

# 测试备份任务（包含 hooks）
log_test "测试带 Hook 的备份任务"
if /app/scripts/backup-job.sh "hook_test"; then
    log_test "✓ 带 Hook 的备份任务执行成功"
else
    log_test "✗ 带 Hook 的备份任务执行失败"
fi

# 检查结果
log_test "检查测试结果"

# 检查是否生成了压缩文件
if ls "$TEST_DIR/backup"/*.tar.xz >/dev/null 2>&1; then
    log_test "✓ 压缩文件已生成"
    ARCHIVE_FILE=$(ls "$TEST_DIR/backup"/*.tar.xz | head -1)
    ARCHIVE_SIZE=$(du -h "$ARCHIVE_FILE" | cut -f1)
    log_test "  压缩文件: $(basename "$ARCHIVE_FILE")"
    log_test "  文件大小: $ARCHIVE_SIZE"
else
    log_test "✗ 未找到压缩文件"
fi

# 检查日志
if [ -f "$BACKUP_LOG_DIR/backup.log" ]; then
    log_test "✓ 备份日志已生成"
    HOOK_LINES=$(grep -c "\[HOOK\]" "$BACKUP_LOG_DIR/backup.log" || echo "0")
    log_test "  Hook 日志条目: $HOOK_LINES"
else
    log_test "✗ 备份日志未生成"
fi

# 显示日志内容（最后20行）
log_test "显示备份日志（最后20行）:"
echo "----------------------------------------"
tail -20 "$BACKUP_LOG_DIR/backup.log" 2>/dev/null || echo "无日志内容"
echo "----------------------------------------"

log_test "Hook 功能测试完成"