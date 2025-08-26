#!/bin/bash

JOB_NAME="$1"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

if [ -z "$JOB_NAME" ]; then
    echo "[$TIMESTAMP] 错误: 未指定备份任务名称"
    exit 1
fi

echo "[$TIMESTAMP] 开始执行备份任务: $JOB_NAME"

# 确保日志目录存在
mkdir -p "$BACKUP_LOG_DIR"

# 从配置文件获取任务详情
job_config=$(jq -r --arg name "$JOB_NAME" '.backup_jobs[] | select(.name == $name and .enabled == true)' "$BACKUP_CONFIG")

if [ -z "$job_config" ] || [ "$job_config" = "null" ]; then
    echo "[$TIMESTAMP] 错误: 找不到启用的备份任务 '$JOB_NAME'"
    exit 1
fi

# 提取任务配置
source_path=$(echo "$job_config" | jq -r '.source_path')
options=$(echo "$job_config" | jq -r '.options[]?' | tr '\n' ' ')
targets=$(echo "$job_config" | jq -r '.targets[] | select(.enabled == true) | @base64')

echo "[$TIMESTAMP] 源路径: $source_path"
echo "[$TIMESTAMP] 备份选项: $options"

# 检查源路径是否存在
if [ ! -d "$source_path" ]; then
    echo "[$TIMESTAMP] 错误: 源路径不存在 '$source_path'"
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
    
    echo "[$TIMESTAMP] 开始备份到: $remote:$remote_path"
    
    # 构建 rclone 命令
    rclone_cmd="rclone copy \"$source_path\" \"$remote:$remote_path\" $options"
    
    # 执行备份
    if eval $rclone_cmd; then
        echo "[$TIMESTAMP] 成功备份到: $remote:$remote_path"
        success_count=$((success_count + 1))
    else
        echo "[$TIMESTAMP] 备份失败: $remote:$remote_path"
    fi
done

echo "[$TIMESTAMP] 备份任务 '$JOB_NAME' 完成: $success_count/$total_count 成功"

if [ $success_count -eq $total_count ]; then
    exit 0
else
    exit 1
fi