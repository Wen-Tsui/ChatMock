#!/bin/bash

# ChatMock 一键启动脚本
# 支持多实例启动和状态监控

set -e

# 配置变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCENE_CONFIG_FILE="$SCRIPT_DIR/chatmock-copilot-config.json"
SIMPLE_CONFIG_FILE="$SCRIPT_DIR/chatmock-simple-config.json"
MANAGER_SCRIPT="$SCRIPT_DIR/chatmock-manager.sh"
LOG_DIR="$SCRIPT_DIR/.logs"
USE_SCENE_CONFIG=true  # 默认使用场景配置

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 创建必要的目录
mkdir -p "$LOG_DIR"

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}=== $1 ===${NC}"
}

# 检查依赖
check_dependencies() {
    print_info "检查依赖..."
    
    # 检查Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python3 未安装"
        exit 1
    fi
    
    # 检查管理脚本
    if [ ! -f "$MANAGER_SCRIPT" ]; then
        print_error "未找到管理脚本: $MANAGER_SCRIPT"
        exit 1
    fi
    
    # 检查配置文件
    if [ "$USE_SCENE_CONFIG" = "true" ]; then
        if [ ! -f "$SCENE_CONFIG_FILE" ]; then
            print_error "未找到场景配置文件: $SCENE_CONFIG_FILE"
            exit 1
        fi
    else
        if [ ! -f "$SIMPLE_CONFIG_FILE" ]; then
            print_error "未找到简化配置文件: $SIMPLE_CONFIG_FILE"
            exit 1
        fi
    fi
    
    # 设置管理脚本权限
    chmod +x "$MANAGER_SCRIPT"
    
    print_success "依赖检查通过"
}

# 显示场景配置
show_scenes() {
    print_header "可用场景配置"
    
    python3 - "$SCENE_CONFIG_FILE" <<'PY'
import json
import sys

SCENE_CONFIG_FILE = sys.argv[1]

DESCRIPTIONS = {
    'daily-coding': '⚡ 日常代码补全 (快速响应)',
    'complex-implementation': '🧠 复杂代码实现 (高质量)',
    'architecture-design': '🏗️ 架构设计 (深度推理)',
    'documentation': '📚 文档生成 (丰富表达)',
    'debugging': '🔍 调试辅助 (精确分析)',
    'task-planning': '📋 任务计划 (系统规划)'
}

def get_scene_description(scene_id: str) -> str:
    return DESCRIPTIONS.get(scene_id, 'N/A')

try:
    with open(SCENE_CONFIG_FILE, 'r', encoding='utf-8') as f:
        cleaned_lines = []
        for line in f:
            stripped = line.lstrip()
            if stripped.startswith('//'):
                continue
            cleaned_lines.append(line)
        config = json.loads(''.join(cleaned_lines))

    print('场景ID\t\t\t显示名称\t\t\t模型\t\t推理\t用途')
    print('-' * 100)

    for model in config.get('oaicopilot.models', []):
        scene_id = model.get('configId', 'N/A')
        display_name = model.get('displayName', 'N/A')
        model_id = model.get('id', 'N/A')
        reasoning = model.get('reasoning_effort', 'N/A')
        print(f"{scene_id:<24}\t{display_name:<24}\t{model_id:<16}\t{reasoning}\t{get_scene_description(scene_id)}")
except Exception as exc:
    print(f'读取场景配置文件失败: {exc}')
PY
}

# 显示简化配置
show_simple_configs() {
    print_header "可用简化配置"
    
    python3 -c "
import json

try:
    with open('$SIMPLE_CONFIG_FILE', 'r') as f:
        config = json.load(f)
    
    print('配置名称\\t\\t端口\\t模型\\t\\t推理\\t描述')
    print('-' * 80)
    
    for name, settings in config.items():
        port = settings.get('port', 'N/A')
        model = settings.get('model', 'N/A')
        reasoning = settings.get('reasoning_effort', 'N/A')
        description = settings.get('description', 'N/A')
        
        print(f'{name:<16}\\t{port:<6}\\t{model:<16}\\t{reasoning:<8}\\t{description}')
        
except Exception as e:
    print(f'读取简化配置文件失败: {e}')
"
}

# 显示配置选项
show_configs() {
    if [ "$USE_SCENE_CONFIG" = "true" ]; then
        show_scenes
    else
        show_simple_configs
    fi
}

# 启动单个场景
start_scene() {
    local scene_id="$1"
    local background="${2:-true}"
    
    print_info "启动场景: $scene_id"
    
    local log_file="$LOG_DIR/manager-$scene_id.log"
    local cmd=("$MANAGER_SCRIPT" start --scene "$scene_id")
    
    if [ "$background" = "true" ]; then
        if ! "${cmd[@]}" > "$log_file" 2>&1; then
            print_error "场景 $scene_id 启动失败，详情见 $log_file"
            return 1
        fi
    else
        if ! "${cmd[@]}"; then
            print_error "场景 $scene_id 启动失败"
            return 1
        fi
    fi
    
    local pid_file="$SCRIPT_DIR/chatmock-$scene_id.pid"
    local retry=0
    while [ ! -f "$pid_file" ] && [ $retry -lt 10 ]; do
        sleep 0.5
        retry=$((retry + 1))
    done
    
    if [ ! -f "$pid_file" ]; then
        print_warning "未找到场景 $scene_id 的 PID 文件，请检查日志"
        return 1
    fi
    
    local pid=$(cat "$pid_file")
    if kill -0 "$pid" 2>/dev/null; then
        print_success "场景 $scene_id 启动完成 (PID: $pid)"
    else
        print_warning "场景 $scene_id 进程未运行，PID: $pid"
    fi
}

# 启动单个配置（兼容简化配置）
start_config() {
    local config_name="$1"
    local background="${2:-true}"
    
    if [ "$USE_SCENE_CONFIG" = "true" ]; then
        start_scene "$config_name" "$background"
    else
        print_info "启动配置: $config_name"
        
        # 读取简化配置
        local config_data=$(python3 -c "
import json
try:
    with open('$SIMPLE_CONFIG_FILE', 'r') as f:
        config = json.load(f)
    if '$config_name' in config:
        print(json.dumps(config['$config_name']))
    else:
        print('null')
except:
    print('null')
")
        
        if [ "$config_data" = "null" ]; then
            print_error "未找到配置: $config_name"
            return 1
        fi
        
        # 解析配置参数
        local host=$(echo "$config_data" | python3 -c "import sys, json; print(json.load(sys.stdin).get('host', '127.0.0.1'))")
        local port=$(echo "$config_data" | python3 -c "import sys, json; print(json.load(sys.stdin).get('port', 8000))")
        local reasoning=$(echo "$config_data" | python3 -c "import sys, json; print(json.load(sys.stdin).get('reasoning_effort', 'medium'))")
        local reasoning_summary=$(echo "$config_data" | python3 -c "import sys, json; print(json.load(sys.stdin).get('reasoning_summary', 'auto'))")
        local web_search=$(echo "$config_data" | python3 -c "import sys, json; print(str(json.load(sys.stdin).get('web_search_enabled', False)).lower())")
        
        # 构建启动命令
        local cmd="$MANAGER_SCRIPT start"
        cmd="$cmd --host $host"
        cmd="$cmd --port $port"
        cmd="$cmd --reasoning $reasoning"
        cmd="$cmd --reasoning-summary $reasoning_summary"
        cmd="$cmd --web-search $web_search"
        cmd="$cmd --verbose"
        
        if [ "$background" = "true" ]; then
            # 后台启动
            nohup $cmd > "$LOG_DIR/chatmock-$config_name.log" 2>&1 &
            local pid=$!
            echo $pid > "$SCRIPT_DIR/chatmock-$config_name.pid"
            print_success "配置 $config_name 启动中 (PID: $pid)"
        else
            # 前台启动
            $cmd
        fi
    fi
}

# 停止单个配置
stop_config() {
    local config_name="$1"
    local pid_file="$SCRIPT_DIR/chatmock-$config_name.pid"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 $pid 2>/dev/null; then
            print_info "停止配置 $config_name (PID: $pid)..."
            kill $pid
            rm -f "$pid_file"
            print_success "配置 $config_name 已停止"
        else
            print_warning "配置 $config_name 的进程 $pid 不存在"
            rm -f "$pid_file"
        fi
    else
        print_warning "未找到配置 $config_name 的PID文件"
    fi
}

# 启动多个配置
start_multiple() {
    local configs=("$@")
    
    print_header "启动多个配置"
    
    for config in "${configs[@]}"; do
        start_config "$config" "true"
        sleep 2  # 避免端口冲突
    done
    
    print_success "所有配置启动完成"
    
    # 等待一下然后显示状态
    sleep 3
    show_status
}

# 启动所有配置
start_all() {
    print_header "启动所有配置"
    
    # 获取所有可用配置
    local all_configs=""
    if [ "$USE_SCENE_CONFIG" = "true" ]; then
        # 获取所有场景配置
        all_configs=$(python3 - "$SCENE_CONFIG_FILE" <<'PY'
import json
import sys

config_path = sys.argv[1]

try:
    with open(config_path, 'r', encoding='utf-8') as f:
        cleaned = []
        for line in f:
            stripped = line.lstrip()
            if stripped.startswith('//'):
                continue
            cleaned.append(line)
        config = json.loads(''.join(cleaned))
    scenes = [model.get('configId') for model in config.get('oaicopilot.models', [])]
    print(' '.join(scenes))
except Exception:
    print('')
PY
)
    else
        # 获取所有简化配置
        all_configs=$(python3 -c "
import json
try:
    with open('$SIMPLE_CONFIG_FILE', 'r') as f:
        config = json.load(f)
    print(' '.join(config.keys()))
except Exception as e:
    print('')
")
    fi
    
    if [ -z "$all_configs" ]; then
        print_error "无法获取配置列表"
        return 1
    fi
    
    print_info "将要启动的配置: $all_configs"
    
    # 启动所有配置
    for config in $all_configs; do
        start_config "$config" "true"
        sleep 2  # 避免端口冲突
    done
    
    print_success "所有配置启动完成"
    
    # 等待服务完全启动并确认状态
    print_info "等待服务完全启动..."
    sleep 5
    
    # 显示最终状态
    show_status
    
    # 执行健康检查
    print_info "执行健康检查..."
    test_all
    
    # 显示启动总结
    print_header "启动总结"
    local running_count=0
    local total_count=0
    
    for pid_file in "$SCRIPT_DIR"/chatmock-*.pid; do
        if [ -f "$pid_file" ]; then
            total_count=$((total_count + 1))
            local pid=$(cat "$pid_file")
            if kill -0 $pid 2>/dev/null; then
                running_count=$((running_count + 1))
            fi
        fi
    done
    
    print_success "成功启动 $running_count/$total_count 个配置实例"
    
    if [ $running_count -eq $total_count ]; then
        print_success "所有配置实例运行正常 ✅"
    else
        print_warning "部分配置实例可能存在问题，请检查日志"
    fi
}

# 停止所有配置
stop_all() {
    print_header "停止所有配置"
    
    # 停止所有通过此脚本启动的实例
    for pid_file in "$SCRIPT_DIR"/chatmock-*.pid; do
        if [ -f "$pid_file" ]; then
            local config_name=$(basename "$pid_file" .pid | sed 's/chatmock-//')
            stop_config "$config_name"
        fi
    done
    
    # 也停止通过管理脚本启动的实例
    if [ -f "$SCRIPT_DIR/chatmock.pid" ]; then
        print_info "停止管理脚本实例..."
        "$MANAGER_SCRIPT" stop
    fi
    
    print_success "所有配置已停止"
}

# 显示所有实例状态
show_status() {
    print_header "服务状态"
    
    echo -e "${CYAN}通过此脚本启动的实例:${NC}"
    echo "配置名称\\t\\tPID\\t\\t端口\\t\\t状态"
    printf '%s\n' "------------------------------------------------------------"
    
    for pid_file in "$SCRIPT_DIR"/chatmock-*.pid; do
        if [ -f "$pid_file" ]; then
            local config_name=$(basename "$pid_file" .pid | sed 's/chatmock-//')
            local pid=$(cat "$pid_file")
            local status="运行中"
            local port="N/A"
            
            if kill -0 $pid 2>/dev/null; then
                # 尝试获取端口信息
                port=$(lsof -Pan -p $pid -iTCP -sTCP:LISTEN -F n 2>/dev/null | sed -n 's/^n.*:\([0-9]*\)$/\1/p' | head -1)
                [ -z "$port" ] && port="N/A"
                status="运行中"
            else
                status="已停止"
                rm -f "$pid_file"
            fi
            
            printf "%-16s\\t%-8s\\t%-8s\\t%s\\n" "$config_name" "$pid" "$port" "$status"
        fi
    done
    
    echo ""
    echo -e "${CYAN}管理脚本实例:${NC}"
    "$MANAGER_SCRIPT" status
}

# 显示日志
show_logs() {
    local config_name="$1"
    local lines="${2:-50}"
    
    if [ -n "$config_name" ]; then
        local log_file="$LOG_DIR/chatmock-$config_name.log"
        if [ -f "$log_file" ]; then
            print_header "配置 $config_name 的日志 (最近 $lines 行)"
            tail -n $lines "$log_file"
        else
            print_warning "未找到配置 $config_name 的日志文件"
        fi
    else
        print_header "所有日志 (最近 $lines 行)"
        for log_file in "$LOG_DIR"/chatmock-*.log; do
            if [ -f "$log_file" ]; then
                local config_name=$(basename "$log_file" .log | sed 's/chatmock-//')
                echo -e "${CYAN}=== $config_name ===${NC}"
                tail -n $lines "$log_file"
                echo ""
            fi
        done
    fi
}

# 测试所有实例
test_all() {
    print_header "测试所有实例"
    
    # 测试通过此脚本启动的实例
    for pid_file in "$SCRIPT_DIR"/chatmock-*.pid; do
        if [ -f "$pid_file" ]; then
            local config_name=$(basename "$pid_file" .pid | sed 's/chatmock-//')
            local pid=$(cat "$pid_file")
            
            if kill -0 $pid 2>/dev/null; then
                print_info "测试配置: $config_name"
                
                # 获取端口
                local port=$(lsof -Pan -p $pid -iTCP -sTCP:LISTEN -F n 2>/dev/null | sed -n 's/^n.*:\([0-9]*\)$/\1/p' | head -1)
                if [ -n "$port" ]; then
                    # 简单的健康检查
                    if curl -s --max-time 3 "http://127.0.0.1:$port/health" > /dev/null 2>&1; then
                        print_success "配置 $config_name (端口 $port) - 健康检查通过"
                    else
                        print_warning "配置 $config_name (端口 $port) - 健康检查失败"
                    fi
                else
                    print_warning "配置 $config_name - 未找到监听端口"
                fi
            fi
        fi
    done
    
    echo ""
    "$MANAGER_SCRIPT" test
}

# 交互式菜单
interactive_menu() {
    while true; do
        clear
        print_header "ChatMock 一键启动脚本"
        
        echo "1. 显示可用配置"
        echo "2. 启动单个配置"
        echo "3. 启动多个配置"
        echo "4. 启动所有配置"
        echo "5. 停止单个配置"
        echo "6. 停止所有配置"
        echo "7. 查看状态"
        echo "8. 查看日志"
        echo "9. 测试服务"
        echo "10. 退出"
        echo ""
        
        read -p "请选择操作 [1-10]: " choice
        
        case $choice in
            1)
                show_configs
                read -p "按回车键继续..."
                ;;
            2)
                show_configs
                echo ""
                read -p "请输入配置名称: " config_name
                if [ -n "$config_name" ]; then
                    start_config "$config_name" "false"
                fi
                ;;
            3)
                show_configs
                echo ""
                read -p "请输入配置名称 (用空格分隔): " -a configs
                if [ ${#configs[@]} -gt 0 ]; then
                    start_multiple "${configs[@]}"
                fi
                read -p "按回车键继续..."
                ;;
            4)
                start_all
                read -p "按回车键继续..."
                ;;
            5)
                show_configs
                echo ""
                read -p "请输入要停止的配置名称: " config_name
                if [ -n "$config_name" ]; then
                    stop_config "$config_name"
                fi
                read -p "按回车键继续..."
                ;;
            6)
                stop_all
                read -p "按回车键继续..."
                ;;
            7)
                show_status
                read -p "按回车键继续..."
                ;;
            8)
                echo "1. 查看所有日志"
                echo "2. 查看特定配置日志"
                read -p "请选择 [1-2]: " log_choice
                case $log_choice in
                    1)
                        read -p "显示行数 [50]: " lines
                        show_logs "" "${lines:-50}"
                        ;;
                    2)
                        show_configs
                        echo ""
                        read -p "请输入配置名称: " config_name
                        read -p "显示行数 [50]: " lines
                        show_logs "$config_name" "${lines:-50}"
                        ;;
                esac
                read -p "按回车键继续..."
                ;;
            9)
                test_all
                read -p "按回车键继续..."
                ;;
            10)
                print_info "退出脚本"
                exit 0
                ;;
            *)
                print_error "无效选择"
                read -p "按回车键继续..."
                ;;
        esac
    done
}

# 显示帮助信息
show_help() {
    echo -e "${PURPLE}ChatMock 一键启动脚本${NC}"
    echo
    echo "用法: $0 [命令] [参数]"
    echo
    echo "命令:"
    echo "  configs                                     显示可用配置"
    echo "  start <配置名>                              启动单个配置"
    echo "  start <配置1> <配置2> ...                   启动多个配置"
    echo "  start all                                   启动所有配置"
    echo "  start-all                                   启动所有配置（别名）"
    echo "  stop <配置名>                               停止单个配置"
    echo "  stop-all                                    停止所有配置"
    echo "  status                                      查看所有实例状态"
    echo "  logs [配置名] [行数]                        查看日志"
    echo "  test                                        测试所有实例"
    echo "  menu                                        交互式菜单"
    echo "  help                                        显示此帮助信息"
    echo
    echo "示例:"
    echo "  $0 configs                                  # 显示可用配置"
    echo "  $0 start fast quality                       # 启动快速和高质量配置"
    echo "  $0 start all                                # 启动所有配置"
    echo "  $0 start-all                                # 启动所有配置（别名）"
    echo "  $0 start default                           # 启动默认配置"
    echo "  $0 stop fast                                # 停止快速配置"
    echo "  $0 stop-all                                 # 停止所有配置"
    echo "  $0 status                                   # 查看状态"
    echo "  $0 logs fast 100                            # 查看快速配置最近100行日志"
    echo "  $0 menu                                     # 交互式菜单"
    echo
    echo "配置文件:"
    echo "  $CONFIG_FILE"
    echo
    echo "管理脚本:"
    echo "  $MANAGER_SCRIPT"
}

# 主函数
main() {
    # 检查依赖
    check_dependencies
    
    case "${1:-menu}" in
         configs)
            show_configs
            ;;
        start)
            shift
            if [ $# -eq 0 ]; then
                print_error "请指定要启动的配置名称"
                show_configs
                exit 1
             elif [ $# -eq 1 ] && [ "$1" = "all" ]; then
                start_all
            elif [ $# -eq 1 ]; then
                start_config "$1" "false"
            else
                start_multiple "$@"
            fi
            ;;
        start-all)
            start_all
            ;;
        stop)
            if [ -z "$2" ]; then
                print_error "请指定要停止的配置名称"
                show_configs
                exit 1
            else
                stop_config "$2"
            fi
            ;;
        stop-all)
            stop_all
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs "$2" "$3"
            ;;
        test)
            test_all
            ;;
        menu)
            interactive_menu
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "未知命令: $1"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
