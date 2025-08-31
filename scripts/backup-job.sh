#!/usr/bin/env bash

# DEBUG 支持
if [[ -n "${DEBUG:-}" ]]; then
    set -eux
else
    set -euo pipefail
fi

JOB_NAME="${1,,}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# 获取日志文件路径
BACKUP_LOG_FILE="${BACKUP_LOG_DIR}/backup.log"

# 日志函数
log_message() {
    local message="$1"
    echo "[$TIMESTAMP] $message" | tee -a "$BACKUP_LOG_FILE"
}

# Hook 执行函数
execute_hook() {
    local hook_type="$1"
    local hook_config="$2"
    
    if [ -z "$hook_config" ] || [ "$hook_config" = "null" ]; then
        return 0
    fi
    
    local enabled=$(echo "$hook_config" | jq -r '.enabled // false')
    if [ "$enabled" != "true" ]; then
        log_message "Hook $hook_type 已禁用，跳过执行"
        return 0
    fi
    
    local script=$(echo "$hook_config" | jq -r '.script')
    local timeout=$(echo "$hook_config" | jq -r '.timeout // 300')
    local fail_on_error=$(echo "$hook_config" | jq -r '.fail_on_error // true')
    local description=$(echo "$hook_config" | jq -r '.description // ""')
    
    if [ ! -f "$script" ]; then
        log_message "警告: Hook 脚本不存在: $script"
        if [ "$fail_on_error" = "true" ]; then
            return 1
        else
            return 0
        fi
    fi
    
    if [ ! -x "$script" ]; then
        log_message "警告: Hook 脚本不可执行: $script"
        if [ "$fail_on_error" = "true" ]; then
            return 1
        else
            return 0
        fi
    fi
    
    log_message "执行 $hook_type hook: $script"
    if [ -n "$description" ]; then
        log_message "Hook 描述: $description"
    fi
    
    # 设置环境变量供 hook 脚本使用
    export BACKUP_JOB_NAME="$JOB_NAME"
    export BACKUP_SOURCE_PATH="$BACKUP_SOURCE_PATH"
    export BACKUP_LOG_FILE="$BACKUP_LOG_FILE"
    
    # 创建临时文件用于 hook 脚本传递更新后的路径
    local hook_output_file="/tmp/backup_hook_${JOB_NAME}_$$"
    export BACKUP_HOOK_OUTPUT_FILE="$hook_output_file"
    
    # 使用 timeout 执行脚本
    if timeout "$timeout" "$script" 2>&1 | tee -a "$BACKUP_LOG_FILE"; then
        log_message "$hook_type hook 执行成功"
        
        # 检查 hook 是否更新了备份源路径
        if [ -f "$hook_output_file" ]; then
            local updated_path=$(cat "$hook_output_file" 2>/dev/null)
            if [ -n "$updated_path" ] && [ -d "$updated_path" ]; then
                BACKUP_SOURCE_PATH="$updated_path"
                log_message "Hook 更新了备份源路径为: $BACKUP_SOURCE_PATH"
            fi
            rm -f "$hook_output_file"
        fi
        
        return 0
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            log_message "错误: $hook_type hook 执行超时 (${timeout}秒)"
        else
            log_message "错误: $hook_type hook 执行失败 (退出码: $exit_code)"
        fi
        
        if [ "$fail_on_error" = "true" ]; then
            return 1
        else
            log_message "忽略 hook 错误，继续执行备份"
            return 0
        fi
    fi
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

# 初始化备份源路径（可能会被 pre-backup hook 修改）
BACKUP_SOURCE_PATH="$source_path"

# 提取 hook 配置
pre_backup_hook=$(echo "$job_config" | jq -r '.hooks.pre_backup // null')
post_backup_hook=$(echo "$job_config" | jq -r '.hooks.post_backup // null')

log_message "源路径: $source_path"
log_message "备份模式: $backup_mode"
log_message "备份选项: $options"

# 检查源路径是否存在
if [ ! -d "$source_path" ]; then
    log_message "错误: 源路径不存在 '$source_path'"
    exit 1
fi

# 执行 pre-backup hook
if ! execute_hook "pre-backup" "$pre_backup_hook"; then
    log_message "错误: pre-backup hook 执行失败，终止备份任务"
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
    
    # 构建 rclone 命令（使用可能被 hook 更新的备份源路径）
    case "$backup_mode" in
        "sync")
            rclone_cmd="rclone sync \"$BACKUP_SOURCE_PATH\" \"$remote:$remote_path\" $options"
            log_message "使用 sync 模式 (会删除目标中不存在于源的文件)"
            ;;
        "copy")
            rclone_cmd="rclone copy \"$BACKUP_SOURCE_PATH\" \"$remote:$remote_path\" $options"
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

# 执行 post-backup hook
if ! execute_hook "post-backup" "$post_backup_hook"; then
    log_message "警告: post-backup hook 执行失败"
fi

# 如果备份成功且使用了压缩，执行清理
if [ $success_count -eq $total_count ] && [ "$BACKUP_SOURCE_PATH" != "$source_path" ]; then
    # 查找清理脚本路径
    CLEANUP_PATH_FILE="/tmp/backup_cleanup_path_${JOB_NAME}_$$"
    if [ -f "$CLEANUP_PATH_FILE" ]; then
        CLEANUP_SCRIPT=$(cat "$CLEANUP_PATH_FILE")
        rm -f "$CLEANUP_PATH_FILE"
        
        if [ -f "$CLEANUP_SCRIPT" ]; then
            log_message "执行压缩文件清理..."
            if bash "$CLEANUP_SCRIPT" 2>&1 | tee -a "$BACKUP_LOG_FILE"; then
                log_message "压缩文件清理完成"
            else
                log_message "警告: 压缩文件清理失败"
            fi
        fi
    fi
fi

if [ $success_count -eq $total_count ]; then
    log_message "所有备份目标都成功完成"
    exit 0
else
    log_message "部分备份目标失败"
    exit 1
fi