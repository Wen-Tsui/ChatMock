#!/bin/bash

# ChatMock Manager Script
# 用于管理 ChatMock 服务的启动、停止和状态查看

set -e

# 配置变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/.logs"
PID_FILE_BASE="$SCRIPT_DIR/chatmock.pid"
LOG_FILE_BASE="$LOG_DIR/chatmock.log"
ERROR_LOG_BASE="$LOG_DIR/chatmock.error.log"
PID_FILE="$PID_FILE_BASE"
LOG_FILE="$LOG_FILE_BASE"
ERROR_LOG="$ERROR_LOG_BASE"
CONFIG_FILE="$SCRIPT_DIR/chatmock-copilot-config.json"
SANITIZED_CONFIG_FILE=""
CONFIG_JSON_PATH="$CONFIG_FILE"
CODEX_HOME="$HOME/.codex"
CURRENT_SCENE_FILE="$SCRIPT_DIR/current_scene.txt"

sanitize_scene_name() {
    local raw="$1"
    if [ -z "$raw" ]; then
        echo ""
        return
    fi
    echo "$raw" | sed 's/[^a-zA-Z0-9._-]/_/g'
}

set_instance_context() {
    local scene_id="$1"
    if [ -n "$scene_id" ]; then
        local safe_scene
        safe_scene=$(sanitize_scene_name "$scene_id")
        PID_FILE="$SCRIPT_DIR/chatmock-$safe_scene.pid"
        LOG_FILE="$LOG_DIR/chatmock-$safe_scene.log"
        ERROR_LOG="$LOG_DIR/chatmock-$safe_scene.error.log"
    else
        PID_FILE="$PID_FILE_BASE"
        LOG_FILE="$LOG_FILE_BASE"
        ERROR_LOG="$ERROR_LOG_BASE"
    fi
}

cleanup_sanitized_file() {
    if [ -n "$SANITIZED_CONFIG_FILE" ] && [ -f "$SANITIZED_CONFIG_FILE" ]; then
        rm -f "$SANITIZED_CONFIG_FILE"
    fi
}

trap cleanup_sanitized_file EXIT

sanitize_config_file() {
    if [ ! -f "$CONFIG_FILE" ]; then
        return
    fi
    
    SANITIZED_CONFIG_FILE=$(mktemp)
    
    if python3 - "$CONFIG_FILE" "$SANITIZED_CONFIG_FILE" <<'PY'; then
import json
import sys

src, dst = sys.argv[1:3]

with open(src, 'r', encoding='utf-8') as f:
    cleaned_lines = []
    for line in f:
        stripped = line.lstrip()
        if stripped.startswith('//'):
            continue
        cleaned_lines.append(line)

data = ''.join(cleaned_lines)
json.loads(data)  # validate

with open(dst, 'w', encoding='utf-8') as f:
    f.write(data)
PY
        CONFIG_JSON_PATH="$SANITIZED_CONFIG_FILE"
    else
        cleanup_sanitized_file
        SANITIZED_CONFIG_FILE=""
        CONFIG_JSON_PATH="$CONFIG_FILE"
    fi
}

sanitize_config_file

# 默认配置
DEFAULT_HOST="127.0.0.1"
DEFAULT_PORT="8001"
DEFAULT_REASONING_EFFORT="medium"
DEFAULT_REASONING_SUMMARY="auto"
DEFAULT_MAX_CONNECTIONS="30"
DEFAULT_TIMEOUT="60"

# 默认的场景 Web 搜索开关，用于补充文档中要求但配置文件未显式声明的值
declare -A SCENE_WEB_SEARCH_DEFAULTS=(
    ["complex-implementation"]="true"
    ["architecture-design"]="true"
    ["documentation"]="true"
    ["debugging"]="true"
    ["task-planning"]="true"
)

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

# 检查 ChatMock 是否已安装
check_chatmock() {
    if ! command -v python3 &> /dev/null; then
        print_error "Python3 未安装，请先安装 Python3"
        exit 1
    fi
    
    if [ ! -f "$SCRIPT_DIR/../chatmock.py" ]; then
        print_error "未找到 chatmock.py 文件，请确保在正确的目录中运行此脚本"
        exit 1
    fi
    
    if ! python3 -c "import sys; sys.path.append('$SCRIPT_DIR/..'); import chatmock" 2>/dev/null; then
        print_error "ChatMock 模块导入失败，请检查安装"
        exit 1
    fi
}

# 检查端口是否被占用
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # 端口被占用
    else
        return 1  # 端口可用
    fi
}

# 获取可用的端口
get_available_port() {
    local port=$1
    while check_port $port; do
        port=$((port + 1))
        if [ $port -gt 8999 ]; then
            print_error "无法找到可用端口 (8000-8999)"
            exit 1
        fi
    done
    echo $port
}

# 从配置文件中获取场景参数
get_scene_config() {
    local scene_id=$1
    local param_name=$2
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo ""
        return 0
    fi
    
    python3 -c "
import json
import sys

def get_config_value():
    try:
        with open('$CONFIG_JSON_PATH', 'r') as f:
            config = json.load(f)
        
        for model in config.get('oaicopilot.models', []):
            if model.get('configId') == '$scene_id':
                value = model.get('$param_name', '')
                if isinstance(value, bool):
                    print(str(value).lower())
                elif isinstance(value, (int, float)):
                    print(str(value))
                elif isinstance(value, str):
                    print(value)
                else:
                    print('')
                return
        print('')
    except Exception as e:
        print('')

get_config_value()
"
}

# 获取场景的推理努力配置
get_scene_reasoning_effort() {
    local scene_id=$1
    local reasoning_effort=$(get_scene_config "$scene_id" "reasoning_effort")
    echo "${reasoning_effort:-$DEFAULT_REASONING_EFFORT}"
}

# 获取场景的推理总结配置
get_scene_reasoning_summary() {
    local scene_id=$1
    if [ -z "$scene_id" ]; then
        echo "$DEFAULT_REASONING_SUMMARY"
        return 0
    fi

    local reasoning_summary=$(get_scene_config "$scene_id" "reasoning_summary")
    if [ -z "$reasoning_summary" ]; then
        reasoning_summary=$(python3 - "$CONFIG_JSON_PATH" "$scene_id" <<'PY'
import json, sys

config_path = sys.argv[1]
scene_id = sys.argv[2]

try:
    with open(config_path, 'r') as f:
        config = json.load(f)
    for model in config.get('oaicopilot.models', []):
        if model.get('configId') == scene_id:
            reasoning = model.get('reasoning') or {}
            if isinstance(reasoning, dict):
                summary = reasoning.get('summary')
                if isinstance(summary, str):
                    print(summary)
                    sys.exit(0)
            break
except Exception:
    pass
print('')
PY
)
    fi

    reasoning_summary=${reasoning_summary:-$DEFAULT_REASONING_SUMMARY}
    echo "$reasoning_summary"
}

# 获取场景的网络搜索配置
get_scene_web_search() {
    local scene_id=$1
    local web_search=$(get_scene_config "$scene_id" "web_search_enabled")
    
    # 检查 extra 字段中的 web_search_enabled
    if [ -z "$web_search" ]; then
        web_search=$(python3 - "$CONFIG_JSON_PATH" "$scene_id" <<'PY'
import json, sys

config_path = sys.argv[1]
scene_id = sys.argv[2]

import sys

try:
    with open(config_path, 'r') as f:
        config = json.load(f)
    for model in config.get('oaicopilot.models', []):
        if model.get('configId') == scene_id:
            extra = model.get('extra') or {}
            if isinstance(extra, dict) and 'web_search_enabled' in extra:
                value = extra.get('web_search_enabled')
                print(str(bool(value)).lower())
                sys.exit(0)
            break
except Exception:
    pass
print('')
PY
)
    fi
    
    if [ -z "$web_search" ]; then
        local default_value="${SCENE_WEB_SEARCH_DEFAULTS[$scene_id]}"
        if [ -n "$default_value" ]; then
            web_search="$default_value"
        fi
    fi
    
    echo "${web_search:-false}"
}

# 获取场景对应的 host
get_scene_host() {
    local scene_id=$1
    [ -n "$scene_id" ] || return 0
    CONFIG_PATH="$CONFIG_JSON_PATH" SCENE_ID="$scene_id" python3 - <<'PY'
import json
import os
from urllib.parse import urlparse

config_path = os.environ["CONFIG_PATH"]
scene_id = os.environ["SCENE_ID"]

try:
    with open(config_path, 'r') as f:
        config = json.load(f)
    for model in config.get('oaicopilot.models', []):
        if model.get('configId') == scene_id:
            url = model.get('baseUrl', '')
            if url:
                parsed = urlparse(url)
                host = parsed.hostname or ''
                if host:
                    print(host)
            break
except Exception:
    pass
PY
}

# 获取场景对应的端口
get_scene_port() {
    local scene_id=$1
    [ -n "$scene_id" ] || return 0
    CONFIG_PATH="$CONFIG_JSON_PATH" SCENE_ID="$scene_id" python3 - <<'PY'
import json
import os
from urllib.parse import urlparse

config_path = os.environ["CONFIG_PATH"]
scene_id = os.environ["SCENE_ID"]

try:
    with open(config_path, 'r') as f:
        config = json.load(f)
    for model in config.get('oaicopilot.models', []):
        if model.get('configId') == scene_id:
            url = model.get('baseUrl', '')
            if url:
                parsed = urlparse(url)
                port = parsed.port
                if port:
                    print(port)
            break
except Exception:
    pass
PY
}

# 获取场景的最大连接数配置
get_scene_max_connections() {
    local scene_id=$1
    # 根据场景类型设置合适的连接数
    case $scene_id in
        "daily-coding")
            echo "50"  # 日常编码需要更多连接
            ;;
        "complex-implementation")
            echo "30"  # 复杂实现中等连接数
            ;;
        "architecture-design")
            echo "20"  # 架构设计较少连接但高质量
            ;;
        "documentation")
            echo "25"  # 文档生成中等连接数
            ;;
        "debugging")
            echo "15"  # 调试需要精确控制
            ;;
        "task-planning")
            echo "20"  # 任务规划中等连接数
            ;;
        *)
            echo "$DEFAULT_MAX_CONNECTIONS"
            ;;
    esac
}

# 获取场景的超时配置
get_scene_timeout() {
    local scene_id=$1
    # 根据场景类型设置合适的超时时间
    case $scene_id in
        "daily-coding")
            echo "30"   # 日常编码快速响应
            ;;
        "complex-implementation")
            echo "60"   # 复杂实现需要更多时间
            ;;
        "architecture-design")
            echo "120"  # 架构设计需要最长时间
            ;;
        "documentation")
            echo "90"   # 文档生成需要较长时间
            ;;
        "debugging")
            echo "45"   # 调试中等时间
            ;;
        "task-planning")
            echo "80"   # 任务计划需要较长时间
            ;;
        *)
            echo "$DEFAULT_TIMEOUT"
            ;;
    esac
}

# 列出所有可用场景
list_scenes() {
    print_header "可用场景"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "未找到配置文件: $CONFIG_FILE"
        return 1
    fi
    
    python3 -c "
import json

def list_scenes():
    try:
        with open('$CONFIG_JSON_PATH', 'r') as f:
            config = json.load(f)
        
        models = config.get('oaicopilot.models', [])
        if not models:
            print('未找到场景配置')
            return
        
        print('场景ID\\t\\t\\t显示名称\\t\\t\\t模型\\t\\t推理努力')
        print('-' * 80)
        
        for model in models:
            scene_id = model.get('configId', 'N/A')
            display_name = model.get('displayName', 'N/A')
            model_id = model.get('id', 'N/A')
            reasoning = model.get('reasoning_effort', 'N/A')
            
            # 格式化输出
            print(f'{scene_id:<24}\\t{display_name:<24}\\t{model_id:<16}\\t{reasoning}')
            
    except Exception as e:
        print(f'读取配置文件失败: {e}')

list_scenes()
"
}

# 启动 ChatMock 服务
start_chatmock() {
    local scene_id=""
    local host=$DEFAULT_HOST
    local port=$DEFAULT_PORT
    local reasoning_effort=$DEFAULT_REASONING_EFFORT
    local reasoning_summary="$DEFAULT_REASONING_SUMMARY"
    local max_connections=$DEFAULT_MAX_CONNECTIONS
    local timeout=$DEFAULT_TIMEOUT
    local enable_web_search=false
    local host_provided=false
    local port_provided=false
    local reasoning_provided=false
    local reasoning_summary_provided=false
    local connections_provided=false
    local timeout_provided=false
    local web_search_provided=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --scene|-s)
                scene_id="$2"
                shift 2
                ;;
            --host|-h)
                host="$2"
                host_provided=true
                shift 2
                ;;
            --port|-p)
                port="$2"
                port_provided=true
                shift 2
                ;;
            --reasoning|-r)
                reasoning_effort="$2"
                reasoning_provided=true
                shift 2
                ;;
            --reasoning-summary)
                reasoning_summary="$2"
                reasoning_summary_provided=true
                shift 2
                ;;
            --connections|-c)
                max_connections="$2"
                connections_provided=true
                shift 2
                ;;
            --timeout|-t)
                timeout="$2"
                timeout_provided=true
                shift 2
                ;;
            --web-search|-w)
                enable_web_search="$2"
                web_search_provided=true
                shift 2
                ;;
            *)
                # 兼容旧格式的位置参数
                if [ -z "$scene_id" ] && [[ "$1" != "127.0.0.1" ]] && [[ "$1" =~ ^[a-zA-Z] ]]; then
                    scene_id="$1"
                elif [ "$1" != "127.0.0.1" ] && [[ "$1" =~ ^[0-9] ]]; then
                    port="$1"
                    port_provided=true
                elif [ "$1" == "127.0.0.1" ]; then
                    host="$1"
                    host_provided=true
                elif [[ "$1" =~ ^(low|medium|high|minimal)$ ]]; then
                    reasoning_effort="$1"
                    reasoning_provided=true
                elif [[ "$1" =~ ^(auto|concise|detailed|none)$ ]]; then
                    reasoning_summary="$1"
                    reasoning_summary_provided=true
                elif [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -gt 10 ]; then
                    max_connections="$1"
                    connections_provided=true
                elif [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -gt 30 ]; then
                    timeout="$1"
                    timeout_provided=true
                elif [[ "$1" =~ ^(true|false)$ ]]; then
                    enable_web_search="$1"
                    web_search_provided=true
                fi
                shift
                ;;
        esac
    done
    
    set_instance_context "$scene_id"

    # 如果指定了场景，从配置文件中获取参数
    if [ -n "$scene_id" ]; then
        print_info "使用场景配置: $scene_id"
        
        # 从配置文件获取参数
        local config_host=""
        local config_port=""
        local config_reasoning=$(get_scene_reasoning_effort "$scene_id")
        local config_reasoning_summary=$(get_scene_reasoning_summary "$scene_id")
        local config_web_search=$(get_scene_web_search "$scene_id")
        local config_connections=$(get_scene_max_connections "$scene_id")
        local config_timeout=$(get_scene_timeout "$scene_id")
        if [ "$host_provided" = "false" ]; then
            config_host=$(get_scene_host "$scene_id")
            [ -n "$config_host" ] && host="$config_host"
        fi
        if [ "$port_provided" = "false" ]; then
            config_port=$(get_scene_port "$scene_id")
            [ -n "$config_port" ] && port="$config_port"
        fi
        
        # 使用配置文件的值，但允许命令行参数覆盖
        [ "$reasoning_provided" = "false" ] && [ -n "$config_reasoning" ] && reasoning_effort="$config_reasoning"
        [ "$reasoning_summary_provided" = "false" ] && [ -n "$config_reasoning_summary" ] && reasoning_summary="$config_reasoning_summary"
        [ "$web_search_provided" = "false" ] && [ -n "$config_web_search" ] && enable_web_search="$config_web_search"
        [ "$connections_provided" = "false" ] && [ -n "$config_connections" ] && max_connections="$config_connections"
        [ "$timeout_provided" = "false" ] && [ -n "$config_timeout" ] && timeout="$config_timeout"
        
        # 获取场景显示名称
        local display_name=$(get_scene_config "$scene_id" "displayName")
        [ -n "$display_name" ] && print_info "场景名称: $display_name"
    fi
    
    # 检查是否已经运行
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        print_warning "ChatMock 服务已在运行中 (PID: $(cat $PID_FILE))"
        return 0
    fi
    
    # 检查端口可用性
    local available_port=$(get_available_port $port)
    if [ $available_port -ne $port ]; then
        print_warning "端口 $port 被占用，使用端口 $available_port"
        port=$available_port
    fi
    
    print_header "启动 ChatMock 服务"
    [ -n "$scene_id" ] && print_info "场景: $scene_id"
    print_info "主机: $host"
    print_info "端口: $port"
    print_info "推理努力: $reasoning_effort"
    print_info "推理总结: $reasoning_summary"
    print_info "最大连接数: $max_connections"
    print_info "超时时间: $timeout 秒"
    print_info "网络搜索: $enable_web_search"
    print_info "日志文件: $LOG_FILE"
    print_info "错误日志: $ERROR_LOG"
    
    # 构建启动命令 - 只使用ChatMock实际支持的参数
    local cmd="cd $SCRIPT_DIR && CODEX_HOME=$CODEX_HOME python3 $SCRIPT_DIR/../chatmock.py serve"
    cmd="$cmd --host $host"
    cmd="$cmd --port $port"
    cmd="$cmd --reasoning-effort $reasoning_effort"
    cmd="$cmd --reasoning-summary $reasoning_summary"
    
    if [ "$enable_web_search" = "true" ]; then
        cmd="$cmd --enable-web-search"
    fi
    
    # 启动服务（后台运行）
    nohup bash -c "$cmd" > "$LOG_FILE" 2> "$ERROR_LOG" &
    local pid=$!
    
    # 保存 PID 和场景信息
    echo $pid > "$PID_FILE"
    if [ -n "$scene_id" ]; then
        echo "$scene_id" > "$CURRENT_SCENE_FILE"
    fi
    
    # 等待服务启动
    print_info "等待服务启动..."
    sleep 3
    
    # 检查服务是否成功启动
    if kill -0 $pid 2>/dev/null; then
        print_success "ChatMock 服务启动成功 (PID: $pid)"
        
        # 测试服务连接
        sleep 2
        if curl -s "http://$host:$port/health" > /dev/null 2>&1; then
            print_success "服务健康检查通过"
            print_info "API 端点: http://$host:$port/v1"
            print_info "健康检查: http://$host:$port/health"
        else
            print_warning "服务启动但健康检查失败，请检查日志"
        fi
    else
        print_error "ChatMock 服务启动失败"
        print_error "请检查错误日志: $ERROR_LOG"
        rm -f "$PID_FILE"
        rm -f "$CURRENT_SCENE_FILE"
        exit 1
    fi
}

# 停止 ChatMock 服务
stop_chatmock() {
    local scene_id=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --scene|-s)
                scene_id="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
    if [ -z "$scene_id" ] && [ -f "$CURRENT_SCENE_FILE" ]; then
        scene_id=$(cat "$CURRENT_SCENE_FILE")
    fi
    set_instance_context "$scene_id"
    if [ ! -f "$PID_FILE" ]; then
        print_warning "未找到 PID 文件，服务可能未运行"
        return 0
    fi
    
    local pid=$(cat "$PID_FILE")
    
    if kill -0 $pid 2>/dev/null; then
        print_info "正在停止 ChatMock 服务 (PID: $pid)..."
        kill $pid
        
        # 等待进程结束
        local count=0
        while kill -0 $pid 2>/dev/null && [ $count -lt 10 ]; do
            sleep 1
            count=$((count + 1))
        done
        
        # 如果进程仍在运行，强制终止
        if kill -0 $pid 2>/dev/null; then
            print_warning "正常停止失败，强制终止进程"
            kill -9 $pid
        fi
        
        print_success "ChatMock 服务已停止"
    else
        print_warning "进程 $pid 不存在"
    fi
    
    rm -f "$PID_FILE"
    if [ -n "$scene_id" ]; then
        if [ -f "$CURRENT_SCENE_FILE" ] && [ "$(cat "$CURRENT_SCENE_FILE")" = "$scene_id" ]; then
            rm -f "$CURRENT_SCENE_FILE"
        fi
    else
        rm -f "$CURRENT_SCENE_FILE"
    fi
}

# 重启 ChatMock 服务
restart_chatmock() {
    stop_chatmock "$@"
    sleep 2
    start_chatmock "$@"
}

# 查看服务状态
status_chatmock() {
    local scene_id=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --scene|-s)
                scene_id="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
    if [ -z "$scene_id" ] && [ -f "$CURRENT_SCENE_FILE" ]; then
        scene_id=$(cat "$CURRENT_SCENE_FILE")
    fi
    set_instance_context "$scene_id"
    print_header "ChatMock 服务状态"
    
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 $pid 2>/dev/null; then
            print_success "服务正在运行 (PID: $pid)"
            
            # 显示当前场景信息
            if [ -f "$CURRENT_SCENE_FILE" ]; then
                local current_scene=$(cat "$CURRENT_SCENE_FILE")
                local display_name=$(get_scene_config "$current_scene" "displayName")
                print_info "当前场景: $current_scene"
                [ -n "$display_name" ] && print_info "场景名称: $display_name"
            fi
            
            # 获取进程信息
            if command -v ps &> /dev/null; then
                print_info "进程信息:"
                ps -p $pid -o pid,ppid,cmd,etime,pcpu,pmem --no-headers 2>/dev/null || print_warning "无法获取进程详细信息"
            fi
            
            # 检查端口监听
            local port=$(lsof -Pi -p $pid -sTCP:LISTEN -t 2>/dev/null | head -1)
            if [ -n "$port" ]; then
                print_success "监听端口: $port"
            else
                print_warning "未找到监听端口"
            fi
            
            # 测试健康检查
            local host=$DEFAULT_HOST
            local port=$DEFAULT_PORT
            
            # 尝试从日志中获取实际端口
            if [ -f "$LOG_FILE" ]; then
                local logged_port=$(grep -o "port [0-9]\+" "$LOG_FILE" | tail -1 | awk '{print $2}')
                if [ -n "$logged_port" ]; then
                    port=$logged_port
                fi
            fi
            
            if curl -s --max-time 5 "http://$host:$port/health" > /dev/null 2>&1; then
                print_success "健康检查: 通过"
                print_info "API 端点: http://$host:$port/v1"
            else
                print_warning "健康检查: 失败"
            fi
            
        else
            print_error "服务未运行 (PID 文件存在但进程不存在)"
            rm -f "$PID_FILE"
            rm -f "$CURRENT_SCENE_FILE"
        fi
    else
        print_warning "服务未运行 (无 PID 文件)"
    fi
    
    # 显示日志文件信息
    if [ -f "$LOG_FILE" ]; then
        local log_size=$(du -h "$LOG_FILE" | cut -f1)
        print_info "日志文件: $LOG_FILE (大小: $log_size)"
    fi
    
    if [ -f "$ERROR_LOG" ]; then
        local error_size=$(du -h "$ERROR_LOG" | cut -f1)
        print_info "错误日志: $ERROR_LOG (大小: $error_size)"
    fi
}

# 查看日志
logs_chatmock() {
    local lines=50
    local scene_id=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --scene|-s)
                scene_id="$2"
                shift 2
                ;;
            --lines)
                lines="$2"
                shift 2
                ;;
            *)
                if [[ "$1" =~ ^[0-9]+$ ]]; then
                    lines="$1"
                fi
                shift
                ;;
        esac
    done
    if [ -z "$scene_id" ] && [ -f "$CURRENT_SCENE_FILE" ]; then
        scene_id=$(cat "$CURRENT_SCENE_FILE")
    fi
    set_instance_context "$scene_id"
    print_header "ChatMock 日志 (最近 $lines 行)"
    
    if [ -f "$LOG_FILE" ]; then
        echo -e "${CYAN}=== 标准输出日志 ===${NC}"
        tail -n $lines "$LOG_FILE"
    else
        print_warning "未找到日志文件: $LOG_FILE"
    fi
    
    if [ -f "$ERROR_LOG" ] && [ -s "$ERROR_LOG" ]; then
        echo -e "\n${RED}=== 错误日志 ===${NC}"
        tail -n $lines "$ERROR_LOG"
    fi
}

# 测试服务
test_chatmock() {
    local scene_id=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --scene|-s)
                scene_id="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
    if [ -z "$scene_id" ] && [ -f "$CURRENT_SCENE_FILE" ]; then
        scene_id=$(cat "$CURRENT_SCENE_FILE")
    fi
    set_instance_context "$scene_id"
    print_header "测试 ChatMock 服务"
    
    # 获取服务地址
    local host=$DEFAULT_HOST
    local port=$DEFAULT_PORT
    
    # 尝试从日志中获取实际端口
    if [ -f "$LOG_FILE" ]; then
        local logged_port=$(grep -o "port [0-9]\+" "$LOG_FILE" | tail -1 | awk '{print $2}')
        if [ -n "$logged_port" ]; then
            port=$logged_port
        fi
    fi
    
    print_info "测试地址: http://$host:$port"
    
    # 测试健康检查
    print_info "执行健康检查..."
    if curl -s "http://$host:$port/health" | python3 -m json.tool 2>/dev/null; then
        print_success "健康检查通过"
    else
        print_error "健康检查失败"
        return 1
    fi
    
    # 测试模型列表
    print_info "获取模型列表..."
    if curl -s "http://$host:$port/v1/models" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    models = [m['id'] for m in data.get('data', [])]
    print('可用模型:')
    for model in models:
        print(f'  - {model}')
except:
    print('模型列表获取失败')
" 2>/dev/null; then
        print_success "模型列表获取成功"
    else
        print_error "模型列表获取失败"
    fi
    
    # 测试聊天完成
    print_info "测试聊天完成..."
    local test_response=$(curl -s -X POST "http://$host:$port/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer key" \
        -d '{
            "model": "gpt-5.1",
            "messages": [{"role": "user", "content": "Hello, ChatMock!"}],
            "reasoning": {"effort": "low"},
            "max_tokens": 50
        }' 2>/dev/null)
    
    if echo "$test_response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    content = data['choices'][0]['message']['content']
    print(f'响应: {content[:100]}...')
    print('聊天完成测试成功')
except:
    print('聊天完成测试失败')
" 2>/dev/null; then
        print_success "聊天完成测试通过"
    else
        print_error "聊天完成测试失败"
        print_error "响应: $test_response"
    fi
}

# 安装 VS Code 配置
install_vscode_config() {
    print_header "安装 VS Code 配置"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "未找到配置文件: $CONFIG_FILE"
        return 1
    fi
    
    # 创建 .vscode 目录
    local vscode_dir="$SCRIPT_DIR/.vscode"
    mkdir -p "$vscode_dir"
    
    # 备份现有配置
    local settings_file="$vscode_dir/settings.json"
    if [ -f "$settings_file" ]; then
        cp "$settings_file" "$settings_file.backup.$(date +%Y%m%d_%H%M%S)"
        print_info "已备份现有配置文件"
    fi
    
    # 提取配置并生成 VS Code settings
python3 -c "
import json

# 读取配置文件
with open('$CONFIG_JSON_PATH', 'r') as f:
    config = json.load(f)

# 生成 VS Code settings
vscode_settings = {
    'oaicopilot.baseUrl': config['oaicopilot.baseUrl'],
    'oaicopilot.models': config['oaicopilot.models']
}

# 保存到 VS Code settings 文件
with open('$settings_file', 'w') as f:
    json.dump(vscode_settings, f, indent=2, ensure_ascii=False)

print('VS Code 配置已安装到: $settings_file')
print('请重启 VS Code 以使配置生效')
"
    
    print_success "VS Code 配置安装完成"
    print_info "配置文件: $settings_file"
    print_info "请在 VS Code 中重新加载窗口以应用配置"
}

# 显示帮助信息
show_help() {
    echo -e "${PURPLE}ChatMock 管理脚本${NC}"
    echo
    echo "用法: $0 [命令] [参数]"
    echo
    echo "命令:"
    echo "  start [选项]                                启动 ChatMock 服务"
    echo "  stop                                        停止 ChatMock 服务"
    echo "  restart [选项]                              重启 ChatMock 服务"
    echo "  status                                      查看服务状态"
    echo "  logs [lines]                                查看日志 (默认 50 行)"
    echo "  test                                        测试服务功能"
    echo "  scenes                                      列出所有可用场景"
    echo "  install-config                              安装 VS Code 配置"
    echo "  help                                        显示此帮助信息"
    echo
    echo "启动选项:"
    echo "  --scene, -s <场景ID>                        使用预定义场景配置"
    echo "  --host, -h <主机>                           绑定主机地址 (默认: 127.0.0.1)"
    echo "  --port, -p <端口>                           端口号 (默认: 8000)"
    echo "  --reasoning, -r <级别>                      推理努力: low/medium/high/minimal"
    echo "  --connections, -c <数量>                    最大连接数 (默认: 30)"
    echo "  --timeout, -t <秒数>                        超时时间 (默认: 60)"
    echo "  --web-search, -w <true/false>               启用网络搜索 (默认: false)"
    echo
    echo "可用场景:"
    echo "  daily-coding                ⚡ 日常代码补全 (快速响应)"
    echo "  complex-implementation     🧠 复杂代码实现 (高质量)"
    echo "  architecture-design         🏗️ 架构设计 (深度推理)"
    echo "  documentation              📚 文档生成 (丰富表达)"
    echo "  debugging                  🔍 调试辅助 (精确分析)"
    echo "  task-planning              📋 任务计划 (系统规划)"
    echo
    echo "示例:"
    echo "  $0 start --scene daily-coding               # 使用日常编码场景启动"
    echo "  $0 start -s architecture-design            # 使用架构设计场景启动"
    echo "  $0 start --host 127.0.0.1 --port 8080      # 自定义主机和端口"
    echo "  $0 start --reasoning high --web-search true # 自定义推理和网络搜索"
    echo "  $0 restart --scene debugging               # 重启为调试场景"
    echo "  $0 scenes                                   # 查看所有场景详情"
    echo "  $0 status                                   # 查看当前状态"
    echo "  $0 logs 100                                 # 查看最近 100 行日志"
    echo "  $0 test                                     # 测试服务"
    echo "  $0 install-config                           # 安装 VS Code 配置"
    echo
    echo "配置文件:"
    echo "  $CONFIG_FILE"
    echo
    echo "日志文件:"
    echo "  $LOG_FILE"
    echo "  $ERROR_LOG"
}
# 主函数
main() {
    case "${1:-help}" in
        start)
            check_chatmock
            shift  # 移除 start 命令，传递剩余参数给 start_chatmock
            start_chatmock "$@"
            ;;
        stop)
            shift
            stop_chatmock "$@"
            ;;
        restart)
            check_chatmock
            shift  # 移除 restart 命令，传递剩余参数给 restart_chatmock
            restart_chatmock "$@"
            ;;
        status)
            shift
            status_chatmock "$@"
            ;;
        logs)
            shift
            logs_chatmock "$@"
            ;;
        test)
            shift
            test_chatmock "$@"
            ;;
        scenes)
            list_scenes
            ;;
        install-config)
            install_vscode_config
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
