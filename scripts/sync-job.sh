#!/usr/bin/env bash

# DEBUG 支持
if [[ -n "${DEBUG:-}" ]]; then
    set -eux
else
    set -euo pipefail
fi

JOB_NAME="$1"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# 获取日志文件路径
SYNC_LOG_FILE="${BACKUP_LOG_DIR}/sync.log"

# 日志函数
log_message() {
    local message="$1"
    echo "[$TIMESTAMP] $message" | tee -a "$SYNC_LOG_FILE"
}

if [ -z "$JOB_NAME" ]; then
    log_message "错误: 未指定同步任务名称"
    exit 1
fi

# 确保日志目录存在
mkdir -p "$BACKUP_LOG_DIR"
touch "$SYNC_LOG_FILE"

log_message "开始执行同步任务: $JOB_NAME"

# 从配置文件获取任务详情
job_config=$(jq -r --arg name "$JOB_NAME" '.sync_jobs[] | select(.name == $name and .enabled == true)' "$BACKUP_CONFIG")

if [ -z "$job_config" ] || [ "$job_config" = "null" ]; then
    log_message "错误: 找不到启用的同步任务 '$JOB_NAME'"
    exit 1
fi

# 提取任务配置
destination_path=$(echo "$job_config" | jq -r '.destination_path')
sync_mode=$(echo "$job_config" | jq -r '.sync_mode // "copy"')
options=$(echo "$job_config" | jq -r '.options[]?' | tr '\n' ' ')
sources=$(echo "$job_config" | jq -r '.sources[] | select(.enabled == true) | @base64')

log_message "目标路径: $destination_path"
log_message "同步模式: $sync_mode"
log_message "拉取选项: $options"

# 确保目标目录存在
mkdir -p "$destination_path"

# 检查目标路径是否可写
if [ ! -w "$destination_path" ]; then
    log_message "错误: 目标路径不可写 '$destination_path'"
    exit 1
fi

# 遍历所有启用的源
success_count=0
total_count=0

for source in $sources; do
    source_data=$(echo "$source" | base64 -d)
    remote=$(echo "$source_data" | jq -r '.remote')
    remote_path=$(echo "$source_data" | jq -r '.path')
    
    total_count=$((total_count + 1))
    
    log_message "开始从 $remote:$remote_path 同步数据"
    
    # 构建 rclone 命令
    case "$sync_mode" in
        "sync")
            rclone_cmd="rclone sync \"$remote:$remote_path\" \"$destination_path\" $options"
            log_message "使用 sync 模式 (会删除目标中不存在于源的文件)"
            ;;
        "copy")
            rclone_cmd="rclone copy \"$remote:$remote_path\" \"$destination_path\" $options"
            log_message "使用 copy 模式 (只复制新文件和更新的文件)"
            ;;
        *)
            log_message "错误: 不支持的同步模式 '$sync_mode'"
            continue
            ;;
    esac
    
    # 执行同步
    if eval $rclone_cmd 2>&1 | tee -a "$SYNC_LOG_FILE"; then
        log_message "成功从 $remote:$remote_path 同步数据"
        success_count=$((success_count + 1))
    else
        log_message "同步失败: $remote:$remote_path"
    fi
done

log_message "同步任务 '$JOB_NAME' 完成: $success_count/$total_count 成功"

if [ $success_count -eq $total_count ]; then
    exit 0
else
    exit 1
fi