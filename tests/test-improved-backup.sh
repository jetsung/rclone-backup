#!/usr/bin/env bash

# 测试改进后的备份脚本

echo "=== 测试改进后的备份脚本 ==="

# 清理之前的测试文件
rm -rf /tmp/test-source /tmp/test-compressed /tmp/backup-compress /tmp/test-backup-target

# 创建测试目录和文件
mkdir -p /tmp/test-source
echo "测试文件1 - $(date)" > /tmp/test-source/file1.txt
echo "测试文件2 - $(date)" > /tmp/test-source/file2.txt
mkdir -p /tmp/test-source/subdir
echo "子目录文件 - $(date)" > /tmp/test-source/subdir/subfile.txt

# 创建测试备份目标目录
mkdir -p /tmp/test-backup-target

# 创建改进的测试 hook 脚本
cat > /tmp/test-improved-compress-hook.sh << 'EOF'
#!/bin/bash
echo "=== 改进的压缩 Hook 开始 ==="
echo "任务名称: $BACKUP_JOB_NAME"
echo "源路径: $BACKUP_SOURCE_PATH"
echo "时间戳: $BACKUP_TIMESTAMP"
echo "Hook 输出文件: $BACKUP_HOOK_OUTPUT_FILE"

# 模拟压缩操作（使用日期格式）
COMPRESS_DIR="/tmp/backup-compress"
mkdir -p "$COMPRESS_DIR"

# 清理旧文件
echo "清理旧的压缩文件..."
find "$COMPRESS_DIR" -name "${BACKUP_JOB_NAME}_*.tar.*" -delete 2>/dev/null || true

# 生成日期格式的文件名
DATE_FORMATTED=$(date '+%Y%m%d')
ARCHIVE_NAME="${BACKUP_JOB_NAME}_${DATE_FORMATTED}.tar.gz"
ARCHIVE_PATH="$COMPRESS_DIR/$ARCHIVE_NAME"

echo "创建压缩包: $ARCHIVE_PATH"
tar -czf "$ARCHIVE_PATH" -C "$(dirname "$BACKUP_SOURCE_PATH")" "$(basename "$BACKUP_SOURCE_PATH")"

if [ $? -eq 0 ]; then
    echo "压缩成功"
    echo "压缩包大小: $(du -h "$ARCHIVE_PATH" | cut -f1)"
    
    # 通知主脚本使用新路径
    if [ -n "${BACKUP_HOOK_OUTPUT_FILE:-}" ]; then
        echo "$COMPRESS_DIR" > "$BACKUP_HOOK_OUTPUT_FILE"
        echo "已通知主脚本使用压缩目录: $COMPRESS_DIR"
    fi
    
    # 创建清理脚本
    cat > "$COMPRESS_DIR/cleanup.sh" << 'CLEANUP_EOF'
#!/bin/bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CLEANUP] 开始清理临时压缩文件和目录"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CLEANUP] 清理压缩文件: ARCHIVE_PATH_PLACEHOLDER"
rm -f "ARCHIVE_PATH_PLACEHOLDER"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CLEANUP] 清理压缩目录: COMPRESS_DIR_PLACEHOLDER"
rm -rf "COMPRESS_DIR_PLACEHOLDER"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CLEANUP] 临时文件清理完成"
CLEANUP_EOF
    
    # 替换占位符
    sed -i "s|ARCHIVE_PATH_PLACEHOLDER|$ARCHIVE_PATH|g" "$COMPRESS_DIR/cleanup.sh"
    sed -i "s|COMPRESS_DIR_PLACEHOLDER|$COMPRESS_DIR|g" "$COMPRESS_DIR/cleanup.sh"
    chmod +x "$COMPRESS_DIR/cleanup.sh"
    
    echo "清理脚本已创建: $COMPRESS_DIR/cleanup.sh"
else
    echo "压缩失败"
    exit 1
fi

echo "=== 改进的压缩 Hook 完成 ==="
EOF

chmod +x /tmp/test-improved-compress-hook.sh

# 创建测试配置
cat > /tmp/test-improved-config.json << 'EOF'
{
  "backup_jobs": [
    {
      "name": "test_improved_backup",
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
          "script": "/tmp/test-improved-compress-hook.sh",
          "timeout": 300,
          "fail_on_error": true,
          "description": "测试改进的压缩备份"
        }
      }
    }
  ]
}
EOF

echo "测试环境准备完成"
echo ""
echo "改进内容:"
echo "1. 使用日期格式文件名 (如: test_improved_backup_20250830.tar.gz)"
echo "2. 只备份当前生成的压缩包"
echo "3. 备份成功后自动清理临时文件和目录"
echo ""
echo "测试文件:"
echo "- 源目录: /tmp/test-source ($(ls /tmp/test-source | wc -l) 个文件)"
echo "- Hook 脚本: /tmp/test-improved-compress-hook.sh"
echo "- 配置文件: /tmp/test-improved-config.json"
echo "- 备份目标: /tmp/test-backup-target"
echo ""
echo "要运行测试，请执行:"
echo "export BACKUP_CONFIG=/tmp/test-improved-config.json"
echo "export BACKUP_LOG_DIR=/tmp/test-logs"
echo "mkdir -p /tmp/test-logs"
echo "bash scripts/backup-job.sh test_improved_backup"
echo ""
echo "预期结果:"
echo "1. 创建日期格式的压缩包 (test_improved_backup_$(date '+%Y%m%d').tar.gz)"
echo "2. 备份压缩包到目标目录"
echo "3. 备份成功后自动清理 /tmp/backup-compress 目录"