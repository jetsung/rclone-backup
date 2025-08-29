#!/usr/bin/env bash

# DEBUG 支持
if [[ -n "${DEBUG:-}" ]]; then
    set -eux
else
    set -euo pipefail
fi

# Hook 创建助手脚本

HOOK_TYPE="$1"
HOOK_NAME="$2"

usage() {
    echo "用法: $0 <hook_type> <hook_name>"
    echo ""
    echo "hook_type: pre-backup 或 post-backup"
    echo "hook_name: hook 脚本的名称（不包含扩展名）"
    echo ""
    echo "示例:"
    echo "  $0 pre-backup compress-photos"
    echo "  $0 post-backup send-notification"
}

if [ -z "$HOOK_TYPE" ] || [ -z "$HOOK_NAME" ]; then
    usage
    exit 1
fi

if [ "$HOOK_TYPE" != "pre-backup" ] && [ "$HOOK_TYPE" != "post-backup" ]; then
    echo "错误: hook_type 必须是 'pre-backup' 或 'post-backup'"
    usage
    exit 1
fi

HOOK_DIR="/app/hooks"
HOOK_FILE="$HOOK_DIR/${HOOK_NAME}.sh"

# 确保 hooks 目录存在
mkdir -p "$HOOK_DIR"

if [ -f "$HOOK_FILE" ]; then
    echo "警告: Hook 文件已存在: $HOOK_FILE"
    read -p "是否覆盖? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "取消创建"
        exit 0
    fi
fi

# 创建 hook 模板
cat > "$HOOK_FILE" << EOF
#!/usr/bin/env bash

# DEBUG 支持
if [[ -n "\${DEBUG:-}" ]]; then
    set -eux
else
    set -euo pipefail
fi

# $HOOK_TYPE hook: $HOOK_NAME
# 创建时间: $(date '+%Y-%m-%d %H:%M:%S')

# 从环境变量获取信息
JOB_NAME="\${BACKUP_JOB_NAME}"
SOURCE_PATH="\${BACKUP_SOURCE_PATH}"
LOG_FILE="\${BACKUP_LOG_FILE}"

# 日志函数
log_hook_message() {
    local message="\$1"
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] [HOOK] \$message" | tee -a "\$LOG_FILE"
}

log_hook_message "开始执行 $HOOK_TYPE hook: $HOOK_NAME"
log_hook_message "任务名称: \$JOB_NAME"
log_hook_message "源路径: \$SOURCE_PATH"

# TODO: 在这里添加您的自定义逻辑
# 示例操作:
# - 压缩文件
# - 发送通知
# - 清理临时文件
# - 生成报告
# - 等等...

log_hook_message "Hook 执行完成: $HOOK_NAME"

# 返回 0 表示成功，非 0 表示失败
exit 0
EOF

# 设置执行权限
chmod +x "$HOOK_FILE"

echo "Hook 创建成功: $HOOK_FILE"
echo ""
echo "接下来的步骤:"
echo "1. 编辑 $HOOK_FILE 添加您的自定义逻辑"
echo "2. 在 config/config.json 中配置相应的备份任务以使用此 hook"
echo ""
echo "配置示例:"
echo "\"hooks\": {"
echo "  \"$HOOK_TYPE\": {"
echo "    \"enabled\": true,"
echo "    \"script\": \"$HOOK_FILE\","
echo "    \"timeout\": 300,"
echo "    \"fail_on_error\": true,"
echo "    \"description\": \"$HOOK_NAME hook 描述\""
echo "  }"
echo "}"