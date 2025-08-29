#!/bin/bash

JOB_NAME="$1"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# 获取日志文件路径
BACKUP_LOG_FILE="${BACKUP_LOG_DIR}/backup.log"

# 日志函数
log_message() {
    local message="$1"
    echo "[$TIMESTAMP] $message" | tee -a "$BACKUP_LOG_FILE"
}

if [ -z "$JOB_NAME" ]; then
    log_message "错误: 未指定备份任务名称"
    exit 1
fi

# 确保日志目录存在
mkdir -p "$BACKUP_LOG_DIR"
touch "$BACKUP_LOG_FILE"

log_message "开始执行备份任务: $JOB_NAME"

# 从配置文件获取任务详情
job_config=$(jq -r --arg name "$JOB_NAME" '.backup_jobs[] | select(.name == $name and .enabled == true)' "$BACKUP_CONFIG")

if [ -z "$job_config" ] || [ "$job_config" = "null" ]; then
    log_message "错误: 找不到启用的备份任务 '$JOB_NAME'"
    exit 1
fi

# 提取任务配置
source_path=$(echo "$job_config" | jq -r '.source_path')
backup_mode=$(echo "$job_config" | jq -r '.backup_mode // "copy"')
options=$(echo "$job_config" | jq -r '.options[]?' | tr '\n' ' ')
targets=$(echo "$job_config" | jq -r '.targets[] | select(.enabled == true) | @base64')

log_message "源路径: $source_path"
log_message "备份模式: $backup_mode"
log_message "备份选项: $options"

# 检查源路径是否存在
if [ ! -d "$source_path" ]; then
    log_message "错误: 源路径不存在 '$source_path'"
    exit 1
fi

# 遍历所有启用的目标
success_count=0
total_count=0

for target in $targets; do
    target_data=$(echo "$target" | base64 -d)
    remote=$(echo "$target_data" | jq -r '.remote')
    remote_path=$(echo "$target_data" | jq -r '.path')
    
    total_count=$((total_count + 1))
    
    log_message "开始备份到: $remote:$remote_path"
    
    # 构建 rclone 命令
    case "$backup_mode" in
        "sync")
            rclone_cmd="rclone sync \"$source_path\" \"$remote:$remote_path\" $options"
            log_message "使用 sync 模式 (会删除目标中不存在于源的文件)"
            ;;
        "copy")
            rclone_cmd="rclone copy \"$source_path\" \"$remote:$remote_path\" $options"
            log_message "使用 copy 模式 (只复制新文件和更新的文件)"
            ;;
        *)
            log_message "错误: 不支持的备份模式 '$backup_mode'"
            continue
            ;;
    esac
    
    # 执行备份
    if eval $rclone_cmd 2>&1 | tee -a "$BACKUP_LOG_FILE"; then
        log_message "成功备份到: $remote:$remote_path"
        success_count=$((success_count + 1))
    else
        log_message "备份失败: $remote:$remote_path"
    fi
done

log_message "备份任务 '$JOB_NAME' 完成: $success_count/$total_count 成功"

if [ $success_count -eq $total_count ]; then
    exit 0
else
    exit 1
fi