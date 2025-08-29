#!/usr/bin/env bash

# 测试清理 BACKUP_TIMESTAMP 后的备份脚本

echo "=== 测试清理 BACKUP_TIMESTAMP 后的备份脚本 ==="

# 清理之前的测试文件
rm -rf /tmp/test-clean-source /tmp/test-clean-compressed /tmp/backup-compress /tmp/test-clean-backup-target

# 创建测试目录和文件
mkdir -p /tmp/test-clean-source
echo "清理测试文件1 - $(date)" > /tmp/test-clean-source/file1.txt
echo "清理测试文件2 - $(date)" > /tmp/test-clean-source/file2.txt

# 创建测试备份目标目录
mkdir -p /tmp/test-clean-backup-target

# 创建清理后的测试 hook 脚本
cat > /tmp/test-clean-compress-hook.sh << 'EOF'
#!/bin/bash
echo "=== 清理后的压缩 Hook 开始 ==="
echo "任务名称: $BACKUP_JOB_NAME"
echo "源路径: $BACKUP_SOURCE_PATH"
echo "日志文件: $BACKUP_LOG_FILE"
echo "Hook 输出文件: $BACKUP_HOOK_OUTPUT_FILE"

# 验证不再有 BACKUP_TIMESTAMP 环境变量
if [ -n "${BACKUP_TIMESTAMP:-}" ]; then
    echo "错误: BACKUP_TIMESTAMP 仍然存在: $BACKUP_TIMESTAMP"
    exit 1
else
    echo "✓ BACKUP_TIMESTAMP 已成功清理"
fi

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

echo "=== 清理后的压缩 Hook 完成 ==="
EOF

chmod +x /tmp/test-clean-compress-hook.sh

# 创建测试配置
cat > /tmp/test-clean-config.json << 'EOF'
{
  "backup_jobs": [
    {
      "name": "test_clean_backup",
      "enabled": true,
      "source_path": "/tmp/test-clean-source",
      "backup_mode": "copy",
      "targets": [
        {
          "remote": "local",
          "path": "/tmp/test-clean-backup-target",
          "enabled": true
        }
      ],
      "options": [
        "--progress"
      ],
      "hooks": {
        "pre_backup": {
          "enabled": true,
          "script": "/tmp/test-clean-compress-hook.sh",
          "timeout": 300,
          "fail_on_error": true,
          "description": "测试清理后的压缩备份"
        }
      }
    }
  ]
}
EOF

echo "测试环境准备完成"
echo ""
echo "清理验证:"
echo "1. BACKUP_TIMESTAMP 环境变量已从所有脚本中移除"
echo "2. 使用 date '+%Y%m%d' 直接生成日期格式"
echo "3. 保持原有功能不变"
echo ""
echo "测试文件:"
echo "- 源目录: /tmp/test-clean-source"
echo "- Hook 脚本: /tmp/test-clean-compress-hook.sh"
echo "- 配置文件: /tmp/test-clean-config.json"
echo "- 备份目标: /tmp/test-clean-backup-target"
echo ""
echo "要运行测试，请执行:"
echo "export BACKUP_CONFIG=/tmp/test-clean-config.json"
echo "export BACKUP_LOG_DIR=/tmp/test-logs"
echo "mkdir -p /tmp/test-logs"
echo "bash scripts/backup-job.sh test_clean_backup"
echo ""
echo "预期结果:"
echo "1. Hook 脚本验证 BACKUP_TIMESTAMP 不存在"
echo "2. 创建日期格式的压缩包 (test_clean_backup_$(date '+%Y%m%d').tar.gz)"
echo "3. 备份和清理功能正常工作"