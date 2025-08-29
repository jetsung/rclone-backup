# 测试文件目录

这个目录包含了用于测试备份系统各种功能的测试脚本。

## 测试文件说明

### 基础测试
- `test-backup-fix.sh` - 测试备份脚本的基本修复功能
- `test-hook-communication.sh` - 测试 hook 脚本与主脚本之间的通信机制

### 功能改进测试
- `test-improved-backup.sh` - 测试改进后的备份功能（日期格式文件名、清理等）
- `test-cleaned-backup.sh` - 测试清理 BACKUP_TIMESTAMP 参数后的功能
- `test-no-cleanup-in-backup.sh` - 测试修复后不再备份 cleanup.sh 文件的功能

### 工具文件
- `fake-rclone.sh` - 模拟 rclone 命令的测试工具

## 运行测试

每个测试脚本都是独立的，可以单独运行：

```bash
# 运行特定测试
bash tests/test-improved-backup.sh

# 按照测试脚本中的说明设置环境变量后运行实际测试
export BACKUP_CONFIG=/tmp/test-config.json
export BACKUP_LOG_DIR=/tmp/test-logs
mkdir -p /tmp/test-logs
bash scripts/backup-job.sh test_job_name
```

## 测试环境

测试脚本会在 `/tmp` 目录下创建临时文件和目录，测试完成后可以手动清理：

```bash
# 清理测试文件
rm -rf /tmp/test-* /tmp/backup-* /tmp/backup_*
```

## 注意事项

- 测试脚本需要在项目根目录下运行
- 某些测试可能会因为缺少 rclone 命令而显示错误，这是正常的
- 测试主要验证脚本逻辑和文件操作，不依赖实际的云存储服务