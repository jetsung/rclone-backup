#!/usr/bin/env bash

# 测试修复后不再备份 cleanup.sh 文件

echo "=== 测试修复后不再备份 cleanup.sh 文件 ==="

# 清理之前的测试文件
rm -rf /tmp/test-no-cleanup-source /tmp/test-no-cleanup-compressed /tmp/backup-compress /tmp/test-no-cleanup-backup-target
rm -f /tmp/backup_cleanup_*

# 创建测试目录和文件
mkdir -p /tmp/test-no-cleanup-source
echo "测试文件1 - $(date)" > /tmp/test-no-cleanup-source/file1.txt
echo "测试文件2 - $(date)" > /tmp/test-no-cleanup-source/file2.txt

# 创建测试备份目标目录
mkdir -p /tmp/test-no-cleanup-backup-target

# 创建测试 hook 脚本
cat > /tmp/test-no-cleanup-compress-hook.sh << 'EOF'
#!/bin/bash
echo "=== 测试不备份 cleanup.sh 的压缩 Hook ==="
echo "任务名称: $BACKUP_JOB_NAME"
echo "源路径: $BACKUP_SOURCE_PATH"
echo "Hook 输出文件: $BACKUP_HOOK_OUTPUT_FILE"

# 模拟压缩操作
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
    
    # 创建清理脚本（放在压缩目录外）
    CLEANUP_SCRIPT="/tmp/backup_cleanup_${BACKUP_JOB_NAME}_$$.sh"
    cat > "$CLEANUP_SCRIPT" << 'CLEANUP_EOF'
#!/bin/bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CLEANUP] 开始清理临时压缩文件和目录"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CLEANUP] 清理压缩文件: ARCHIVE_PATH_PLACEHOLDER"
rm -f "ARCHIVE_PATH_PLACEHOLDER"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CLEANUP] 清理压缩目录: COMPRESS_DIR_PLACEHOLDER"
rm -rf "COMPRESS_DIR_PLACEHOLDER"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CLEANUP] 清理脚本自身: CLEANUP_SCRIPT_PLACEHOLDER"
rm -f "CLEANUP_SCRIPT_PLACEHOLDER"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CLEANUP] 临时文件清理完成"
CLEANUP_EOF
    
    # 替换占位符
    sed -i "s|ARCHIVE_PATH_PLACEHOLDER|$ARCHIVE_PATH|g" "$CLEANUP_SCRIPT"
    sed -i "s|COMPRESS_DIR_PLACEHOLDER|$COMPRESS_DIR|g" "$CLEANUP_SCRIPT"
    sed -i "s|CLEANUP_SCRIPT_PLACEHOLDER|$CLEANUP_SCRIPT|g" "$CLEANUP_SCRIPT"
    chmod +x "$CLEANUP_SCRIPT"
    
    # 将清理脚本路径写入文件供主脚本使用
    echo "$CLEANUP_SCRIPT" > "/tmp/backup_cleanup_path_${BACKUP_JOB_NAME}_$$"
    
    echo "清理脚本已创建: $CLEANUP_SCRIPT"
    echo "清理脚本路径已保存到: /tmp/backup_cleanup_path_${BACKUP_JOB_NAME}_$$"
else
    echo "压缩失败"
    exit 1
fi

echo "=== 压缩 Hook 完成 ==="
EOF

chmod +x /tmp/test-no-cleanup-compress-hook.sh

# 创建测试配置
cat > /tmp/test-no-cleanup-config.json << 'EOF'
{
  "backup_jobs": [
    {
      "name": "test_no_cleanup_backup",
      "enabled": true,
      "source_path": "/tmp/test-no-cleanup-source",
      "backup_mode": "copy",
      "targets": [
        {
          "remote": "local",
          "path": "/tmp/test-no-cleanup-backup-target",
          "enabled": true
        }
      ],
      "options": [
        "--progress"
      ],
      "hooks": {
        "pre_backup": {
          "enabled": true,
          "script": "/tmp/test-no-cleanup-compress-hook.sh",
          "timeout": 300,
          "fail_on_error": true,
          "description": "测试不备份 cleanup.sh 的压缩"
        }
      }
    }
  ]
}
EOF

echo "测试环境准备完成"
echo ""
echo "修复验证:"
echo "1. cleanup.sh 文件不再放在备份目录中"
echo "2. cleanup.sh 放在独立的临时位置"
echo "3. 备份目录中只包含压缩包文件"
echo ""
echo "测试文件:"
echo "- 源目录: /tmp/test-no-cleanup-source"
echo "- Hook 脚本: /tmp/test-no-cleanup-compress-hook.sh"
echo "- 配置文件: /tmp/test-no-cleanup-config.json"
echo "- 备份目标: /tmp/test-no-cleanup-backup-target"
echo ""
echo "要运行测试，请执行:"
echo "export BACKUP_CONFIG=/tmp/test-no-cleanup-config.json"
echo "export BACKUP_LOG_DIR=/tmp/test-logs"
echo "mkdir -p /tmp/test-logs"
echo "bash scripts/backup-job.sh test_no_cleanup_backup"
echo ""
echo "预期结果:"
echo "1. 备份目录中只有压缩包文件，没有 cleanup.sh"
echo "2. cleanup.sh 在独立位置创建和执行"
echo "3. 备份完成后所有临时文件被清理"