# ChatMock 管理工具使用指南

本目录包含了 ChatMock 服务的完整管理工具，支持多场景配置、后台运行和状态监控。

## 📁 文件说明

### 配置文件
- **`chatmock-copilot-config.json`** - 完整的多场景 VS Code Copilot 配置
- **`CHATMOCK_MANAGER_README.md`** - 本使用说明文档

### 管理脚本
- **`chatmock-manager.sh`** - 完整的管理脚本（支持所有功能）
- **`start-chatmock.sh`** - 快速启动脚本（简化版）

### 日志目录
- **`logs/`** - 自动创建的日志目录
  - `chatmock.log` - 标准输出日志
  - `chatmock.error.log` - 错误日志

## 🚀 快速开始

### 1. 交互式启动（推荐）
```bash
./start-chatmock.sh
```
运行后会显示场景选择菜单：
- ⚡ 日常代码补全 - 快速响应，适合日常编码
- 🧠 复杂代码实现 - 高质量代码，适合算法实现  
- 🏗️ 架构设计 - 深度推理，适合系统设计
- 📚 文档生成 - 丰富表达，适合技术文档
- 🔍 调试辅助 - 精确分析，适合问题诊断
- 📋 任务计划 - 系统规划，适合项目管理
- 🎛️ 自定义配置 - 手动指定启动参数

### 2. 场景化启动
```bash
# 使用特定场景启动
./chatmock-manager.sh start --scene daily-coding
./chatmock-manager.sh start --scene architecture-design
./chatmock-manager.sh start --scene debugging

# 查看所有可用场景
./chatmock-manager.sh scenes
```

### 3. 手动管理
```bash
# 启动服务（默认配置）
./chatmock-manager.sh start

# 查看状态
./chatmock-manager.sh status

# 查看日志
./chatmock-manager.sh logs

# 测试服务
./chatmock-manager.sh test
```

## 📋 完整功能说明

### 服务管理

#### 场景化启动（推荐）
```bash
# 使用预定义场景启动
./chatmock-manager.sh start --scene <场景ID>

# 可用场景：
./chatmock-manager.sh start --scene daily-coding           # 日常代码补全
./chatmock-manager.sh start --scene complex-implementation # 复杂代码实现
./chatmock-manager.sh start --scene architecture-design    # 架构设计
./chatmock-manager.sh start --scene documentation         # 文档生成
./chatmock-manager.sh start --scene debugging             # 调试辅助
./chatmock-manager.sh start --scene task-planning         # 任务计划

# 查看所有场景详情
./chatmock-manager.sh scenes
```

#### 自定义参数启动
```bash
# 使用命令行参数启动
./chatmock-manager.sh start --host 127.0.0.1 --port 8000 --reasoning high --web-search true

# 兼容旧格式（不推荐）
./chatmock-manager.sh start 127.0.0.1 8000 high 50 120 true
```

**启动选项：**
- `--scene, -s <场景ID>` - 使用预定义场景配置
- `--host, -h <主机>` - 绑定主机地址（默认: 127.0.0.1）
- `--port, -p <端口>` - 端口号（默认: 8000）
- `--reasoning, -r <级别>` - 推理努力：low/medium/high/minimal
- `--connections, -c <数量>` - 最大连接数（默认: 30）
- `--timeout, -t <秒数>` - 超时时间（默认: 60）
- `--web-search, -w <true/false>` - 启用网络搜索（默认: false）

#### 停止服务
```bash
./chatmock-manager.sh stop
```

#### 重启服务
```bash
# 重启当前服务
./chatmock-manager.sh restart

# 重启并切换场景
./chatmock-manager.sh restart --scene debugging

# 重启并使用新参数
./chatmock-manager.sh restart --reasoning high --web-search true
```

### 状态监控

#### 查看服务状态
```bash
./chatmock-manager.sh status
```

输出示例：
```
=== ChatMock 服务状态 ===
[SUCCESS] 服务正在运行 (PID: 12345)
[INFO] 当前场景: daily-coding
[INFO] 场景名称: ⚡ Daily Coding
[INFO] 进程信息:
12345 12344 python3 chatmock.py serve --host 127.0.0.1 --port 8000 ...
[SUCCESS] 监听端口: 8000
[SUCCESS] 健康检查: 通过
[INFO] API 端点: http://127.0.0.1:8000/v1
[INFO] 日志文件: logs/chatmock.log (大小: 1.2M)
[INFO] 错误日志: logs/chatmock.error.log (大小: 0B)
```

#### 查看场景信息
```bash
# 列出所有可用场景
./chatmock-manager.sh scenes

# 查看当前运行场景
./chatmock-manager.sh status | grep "当前场景"
```

#### 查看日志
```bash
# 查看最近 50 行日志
./chatmock-manager.sh logs

# 查看最近 100 行日志
./chatmock-manager.sh logs 100

# 实时监控日志
tail -f logs/chatmock.log
tail -f logs/chatmock.error.log
```

### 服务测试

#### 完整功能测试
```bash
./chatmock-manager.sh test
```

测试内容包括：
- 健康检查
- 模型列表获取
- 聊天完成功能

### VS Code 配置

#### 安装 Copilot 配置
```bash
./chatmock-manager.sh install-config
```

这将会：
1. 创建 `.vscode/settings.json` 文件
2. 自动应用多场景配置
3. 备份现有配置文件

## 🎯 多场景配置

配置文件包含 6 个预定义场景：

| 场景ID | 显示名称 | 模型 | 推理努力 | 温度 | 连接数 | 超时 | 网络搜索 | 用途 |
|--------|----------|------|----------|------|--------|------|----------|------|
| daily-coding | ⚡ Daily Coding | gpt-5.1-codex-mini | low | 0.1 | 50 | 30s | false | 快速代码补全 |
| complex-implementation | 🧠 Complex Implementation | gpt-5.1-codex | medium | 0.2 | 30 | 60s | false | 算法实现 |
| architecture-design | 🏗️ Architecture Design | gpt-5.1 | high | 0.3 | 20 | 120s | true | 系统设计 |
| documentation | 📚 Documentation | gpt-5.1 | medium | 0.7 | 25 | 90s | true | 技术文档 |
| debugging | 🔍 Debugging Assistant | gpt-5.1-codex | high | 0.0 | 15 | 45s | false | 问题诊断 |
| task-planning | 📋 Task Planning | gpt-5.1 | high | 0.4 | 20 | 80s | true | 项目规划 |

### 场景特性说明

#### ⚡ 日常代码补全 (daily-coding)
- **优化目标**: 快速响应、低延迟
- **适用场景**: 日常编码、简单函数实现、代码片段补全
- **启动命令**: `./chatmock-manager.sh start --scene daily-coding`

#### 🧠 复杂代码实现 (complex-implementation)
- **优化目标**: 代码质量、逻辑正确性、性能优化
- **适用场景**: 算法实现、复杂业务逻辑、数据处理
- **启动命令**: `./chatmock-manager.sh start --scene complex-implementation`

#### 🏗️ 架构设计 (architecture-design)
- **优化目标**: 全面思考、最佳实践、可扩展性
- **适用场景**: 系统架构设计、技术选型、设计模式应用
- **启动命令**: `./chatmock-manager.sh start --scene architecture-design`

#### 📚 文档生成 (documentation)
- **优化目标**: 语言表达清晰、结构完整、用户友好
- **适用场景**: API 文档、用户手册、技术规范、README
- **启动命令**: `./chatmock-manager.sh start --scene documentation`

#### 🔍 调试辅助 (debugging)
- **优化目标**: 精确分析、快速定位问题、提供解决方案
- **适用场景**: 错误诊断、问题排查、性能优化、代码审查
- **启动命令**: `./chatmock-manager.sh start --scene debugging`

#### 📋 任务计划 (task-planning)
- **优化目标**: 系统性思考、可行性分析、详细规划
- **适用场景**: 项目规划、任务分解、时间管理、资源分配
- **启动命令**: `./chatmock-manager.sh start --scene task-planning`

## 🔧 高级用法

### 自定义配置

#### 修改配置文件
编辑 `chatmock-copilot-config.json` 来自定义模型配置：

```json
{
  "oaicopilot.baseUrl": "http://127.0.0.1:8000/v1",
  "oaicopilot.models": [
    {
      "id": "gpt-5.1",
      "owned_by": "chatmock",
      "configId": "custom",
      "displayName": "自定义模型",
      "temperature": 0.5,
      "reasoning_effort": "medium"
    }
  ]
}
```

#### 环境特定配置

**开发环境配置：**
```bash
./chatmock-manager.sh start 127.0.0.1 8000 low 50 30 false
```

**生产环境配置：**
```bash
./chatmock-manager.sh start 0.0.0.0 8000 high 20 120 true
```

### 后台运行管理

#### 查看进程
```bash
# 查看 ChatMock 进程
ps aux | grep chatmock

# 查看端口占用
lsof -i :8000
```

#### 手动清理
```bash
# 如果脚本无法正常停止，手动清理
pkill -f chatmock.py
rm -f chatmock.pid
```

## 🛠️ 故障排除

### 常见问题

#### 1. 端口被占用
```bash
# 查看端口占用
netstat -tlnp | grep :8000

# 脚本会自动选择可用端口
./chatmock-manager.sh start 127.0.0.1 8001
```

#### 2. 服务启动失败
```bash
# 查看错误日志
./chatmock-manager.sh logs

# 检查 Python 环境
python3 --version
python3 -c "import chatmock"
```

#### 3. VS Code 配置问题
```bash
# 重新安装配置
./chatmock-manager.sh install-config

# 检查配置文件
cat .vscode/settings.json
```

#### 4. 权限问题
```bash
# 添加执行权限
chmod +x chatmock-manager.sh
chmod +x start-chatmock.sh
```

### 日志分析

#### 查看启动日志
```bash
# 查看完整启动日志
cat logs/chatmock.log

# 查看错误信息
cat logs/chatmock.error.log

# 搜索特定信息
grep "error" logs/chatmock.log
grep "port" logs/chatmock.log
```

## 📊 性能监控

### 系统资源监控
```bash
# 查看进程资源使用
top -p $(cat chatmock.pid)

# 查看内存使用
ps aux | grep chatmock

# 查看网络连接
netstat -an | grep :8000
```

### 性能优化建议

#### 高性能配置
```bash
# 高并发、低延迟
./chatmock-manager.sh start 127.0.0.1 8000 low 50 30 false
```

#### 高质量配置
```bash
# 高质量、强推理
./chatmock-manager.sh start 127.0.0.1 8000 high 20 120 true
```

## 🔄 自动化脚本

### 创建系统服务（可选）

创建 systemd 服务文件 `/etc/systemd/system/chatmock.service`：

```ini
[Unit]
Description=ChatMock Service
After=network.target

[Service]
Type=forking
User=Wen-Tsui
WorkingDirectory=/home/Wen-Tsui/ChatMock
ExecStart=/home/Wen-Tsui/ChatMock/chatmock-manager.sh start
ExecStop=/home/Wen-Tsui/ChatMock/chatmock-manager.sh stop
ExecReload=/home/Wen-Tsui/ChatMock/chatmock-manager.sh restart
PIDFile=/home/Wen-Tsui/ChatMock/chatmock.pid
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

启用服务：
```bash
sudo systemctl enable chatmock
sudo systemctl start chatmock
sudo systemctl status chatmock
```

## 📝 使用示例

### 典型工作流程

```bash
# 1. 交互式启动（推荐）
./start-chatmock.sh

# 2. 或者场景化启动
./chatmock-manager.sh start --scene daily-coding

# 3. 安装 VS Code 配置
./chatmock-manager.sh install-config

# 4. 测试服务
./chatmock-manager.sh test

# 5. 在 VS Code 中使用 Copilot Chat

# 6. 监控状态
./chatmock-manager.sh status

# 7. 查看日志
./chatmock-manager.sh logs

# 8. 切换场景（如需要）
./chatmock-manager.sh restart --scene debugging

# 9. 停止服务
./chatmock-manager.sh stop
```

### 开发环境快速切换

```bash
# 日常编码模式 - 快速响应
./chatmock-manager.sh restart --scene daily-coding

# 调试模式 - 精确分析
./chatmock-manager.sh restart --scene debugging

# 架构设计模式 - 深度推理
./chatmock-manager.sh restart --scene architecture-design

# 文档生成模式 - 丰富表达
./chatmock-manager.sh restart --scene documentation
```

### 场景切换最佳实践

```bash
# 查看当前运行场景
./chatmock-manager.sh status | grep "当前场景"

# 快速切换到调试模式
./chatmock-manager.sh restart --scene debugging

# 切换到日常编码模式
./chatmock-manager.sh restart --scene daily-coding

# 查看所有可用场景
./chatmock-manager.sh scenes
```

## 🆘 获取帮助

```bash
# 查看完整帮助
./chatmock-manager.sh help

# 快速参考
./start-chatmock.sh  # 显示常用命令
```

---

## 📞 支持

如果遇到问题，请：
1. 查看日志文件：`logs/chatmock.error.log`
2. 运行测试：`./chatmock-manager.sh test`
3. 检查配置：`./chatmock-manager.sh status`
4. 查看帮助：`./chatmock-manager.sh help`

享受使用 ChatMock 的强大功能！🎉
