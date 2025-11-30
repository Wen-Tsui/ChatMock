# OAI Compatible Provider for Copilot 配置 ChatMock 详细指南

## 概述

通过使用 **"OAI Compatible Provider for Copilot"** VS Code 扩展，您可以将 ChatMock 与 GitHub Copilot 集成，在 Copilot Chat 界面中使用 GPT-5.1 系列模型的强大功能。本指南将详细介绍如何配置该扩展以连接到 ChatMock。

## 前置条件

1. **已安装并运行 ChatMock**
   ```bash
   # 登录 ChatGPT 账户
   python3 chatmock.py login
   
   # 启动 ChatMock 服务器
   python3 chatmock.py serve
   ```

2. **确认 ChatMock 服务运行状态**
   ```bash
   # 测试健康检查
   curl http://127.0.0.1:8000/health
   
   # 查看可用模型
   curl http://127.0.0.1:8000/v1/models
   ```

3. **已安装必要扩展**
   - VS Code 扩展: **"OAI Compatible Provider for Copilot"** (by Johnny Zhao)
   - VS Code 扩展: GitHub Copilot

## 快速开始

### 步骤 1：安装 OAI Compatible Provider 扩展
1. 打开 VS Code 扩展市场 (`Ctrl/Cmd + Shift + X`)
2. 搜索 "OAI Compatible Provider for Copilot"
3. 安装作者为 Johnny Zhao 的扩展

### 步骤 2：配置基础设置
打开 VS Code 设置 (`Ctrl/Cmd + ,`)，添加以下配置：

```json
{
  "oaicopilot.baseUrl": "http://127.0.0.1:8000/v1",
  "oaicopilot.models": [
    {
      "id": "gpt-5.1",
      "owned_by": "chatmock",
      "temperature": 0.7,
      "top_p": 1,
      "reasoning_effort": "medium"
    }
  ]
}
```

### 步骤 3：配置 API 密钥
1. 打开命令面板 (`Ctrl/Cmd + Shift + P`)
2. 搜索 "OAICopilot: Set OAI Compatible Multi-Provider Apikey"
3. 输入 provider 名称：`chatmock`
4. 输入 API 密钥：`key`（ChatMock 会忽略此值，但需要填写）

### 步骤 4：在 Copilot Chat 中使用
1. 打开 GitHub Copilot Chat 界面 (`Ctrl/Cmd + Alt + I`)
2. 点击模型选择器，选择 "Manage Models..."
3. 选择 "OAI Compatible" provider
4. 选择要添加的模型（如 gpt-5.1）
5. 开始在 Copilot Chat 中使用 ChatMock 模型

## 推荐模型配置

### 基础配置示例

#### 单模型配置
```json
{
  "oaicopilot.baseUrl": "http://127.0.0.1:8000/v1",
  "oaicopilot.models": [
    {
      "id": "gpt-5.1",
      "owned_by": "chatmock",
      "displayName": "ChatMock GPT-5.1",
      "context_length": 128000,
      "max_tokens": 8192,
      "temperature": 0.7,
      "top_p": 1,
      "reasoning_effort": "medium"
    }
  ]
}
```

#### 多模型配置
```json
{
  "oaicopilot.baseUrl": "http://127.0.0.1:8000/v1",
  "oaicopilot.models": [
    {
      "id": "gpt-5.1",
      "owned_by": "chatmock",
      "configId": "high-reasoning",
      "displayName": "GPT-5.1 (High Reasoning)",
      "temperature": 0.7,
      "top_p": 1,
      "reasoning_effort": "high"
    },
    {
      "id": "gpt-5.1-codex",
      "owned_by": "chatmock",
      "configId": "coding",
      "displayName": "GPT-5.1 Codex",
      "temperature": 0,
      "top_p": 1,
      "reasoning_effort": "medium"
    },
    {
      "id": "gpt-5.1-codex-mini",
      "owned_by": "chatmock",
      "configId": "fast-coding",
      "displayName": "GPT-5.1 Codex Mini",
      "temperature": 0,
      "top_p": 1,
      "reasoning_effort": "low"
    }
  ]
}
```

### 高级配置示例

#### 多配置同一模型（类似用户提供的示例）
```json
{
  "oaicopilot.baseUrl": "http://127.0.0.1:8000/v1",
  "oaicopilot.models": [
    {
      "id": "gpt-5.1",
      "configId": "thinking",
      "owned_by": "chatmock",
      "temperature": 0.7,
      "top_p": 1,
      "reasoning_effort": "high",
      "enable_thinking": true
    },
    {
      "id": "gpt-5.1",
      "configId": "no-thinking",
      "owned_by": "chatmock",
      "temperature": 0,
      "top_p": 1,
      "reasoning_effort": "low",
      "enable_thinking": false
    }
  ]
}
```

### 不同场景的模型选择

| 场景 | 推荐模型配置 | 特点 |
|------|-------------|------|
| 日常代码补全 | `gpt-5.1-codex-mini` + `reasoning_effort: "low"` | 响应快速，资源占用少 |
| 复杂算法实现 | `gpt-5.1-codex` + `reasoning_effort: "medium"` | 代码质量高，逻辑性强 |
| 架构设计 | `gpt-5.1` + `reasoning_effort: "high"` | 推理能力强，适合复杂问题 |
| 文档生成 | `gpt-5.1` + `temperature: 0.7` | 语言表达优秀 |
| 调试辅助 | `gpt-5.1-codex` + `temperature: 0` | 代码分析能力强 |
| 快速原型 | `gpt-5.1-codex-mini` + `temperature: 0.2` | 快速迭代，创意编程 |

## 场景化配置详解

### 1. 日常代码补全配置

**适用场景**：日常编码、简单函数实现、代码片段补全
**优化目标**：快速响应、低延迟、减少资源消耗

```json
{
  "oaicopilot.baseUrl": "http://127.0.0.1:8000/v1",
  "oaicopilot.models": [
    {
      "id": "gpt-5.1-codex-mini",
      "owned_by": "chatmock",
      "configId": "daily-coding",
      "displayName": "⚡ Daily Coding",
      "temperature": 0.02,
      "top_p": 0.98,
      "max_tokens": 1024,
      "reasoning_effort": "medium",
      "frequency_penalty": 0.15,
      "presence_penalty": 0.08,
      "context_length": 32000
    }
  ]
}
```

**参数说明**：
- `temperature: 0.1` - 低随机性，确保代码一致性
- `max_tokens: 1024` - 限制输出长度，提高响应速度
- `reasoning_effort: "low"` - 最小推理努力，快速响应
- `frequency_penalty: 0.1` - 轻微减少重复代码

**ChatMock 启动参数**：
```bash
python3 chatmock.py serve --reasoning-effort medium
```

### 2. 复杂代码实现配置

**适用场景**：算法实现、复杂业务逻辑、数据处理
**优化目标**：代码质量、逻辑正确性、性能优化

```json
{
  "oaicopilot.baseUrl": "http://127.0.0.1:8000/v1",
  "oaicopilot.models": [
    {
      "id": "gpt-5.1-codex",
      "owned_by": "chatmock",
      "configId": "complex-implementation",
      "displayName": "🧠 Complex Implementation",
      "temperature": 0.15,
      "top_p": 0.92,
      "max_tokens": 6144,
      "reasoning_effort": "medium",
      "frequency_penalty": 0.3,
      "presence_penalty": 0.2,
      "context_length": 96000,
      "enable_thinking": true,
      "thinking_budget": 4000
    }
  ]
}
```

**参数说明**：
- `temperature: 0.2` - 适度创造性，平衡创新和稳定性
- `reasoning_effort: "medium"` - 中等推理努力，确保逻辑正确
- `enable_thinking: true` - 显示思维过程，便于理解实现思路
- `max_tokens: 4096` - 支持较长代码实现
- `thinking_budget: 2000` - 为复杂推理预留足够空间

**ChatMock 启动参数**：
```bash
python3 chatmock.py serve --reasoning-effort medium --enable-web-search
```

### 3. 架构设计配置

**适用场景**：系统架构设计、技术选型、设计模式应用
**优化目标**：全面思考、最佳实践、可扩展性

```json
{
  "oaicopilot.baseUrl": "http://127.0.0.1:8000/v1",
  "oaicopilot.models": [
    {
      "id": "gpt-5.1",
      "owned_by": "chatmock",
      "configId": "architecture-design",
      "displayName": "🏗️ Architecture Design",
      "temperature": 0.28,
      "top_p": 0.96,
      "max_tokens": 10240,
      "reasoning_effort": "high",
      "frequency_penalty": 0.4,
      "presence_penalty": 0.3,
      "context_length": 200000,
      "enable_thinking": true,
      "thinking_budget": 8000
    }
  ]
}
```

**参数说明**：
- `temperature: 0.3` - 适度创造性，鼓励创新架构方案
- `reasoning_effort: "high"` - 最高推理努力，深度思考架构问题
- `thinking_budget: 4000` - 充分的推理空间处理复杂架构
- `max_tokens: 8192` - 支持详细的架构文档和说明
- `extra` 中的参数确保考虑可扩展性、安全性和最佳实践

**ChatMock 启动参数**：
```bash
python3 chatmock.py serve --reasoning-effort high --enable-web-search
```

### 4. 文档生成配置

**适用场景**：API 文档、用户手册、技术规范、README
**优化目标**：语言表达清晰、结构完整、用户友好

```json
{
  "oaicopilot.baseUrl": "http://127.0.0.1:8000/v1",
  "oaicopilot.models": [
    {
      "id": "gpt-5.1",
      "owned_by": "chatmock",
      "configId": "documentation",
      "displayName": "📚 Documentation",
      "temperature": 0.72,
      "top_p": 0.92,
      "max_tokens": 8192,
      "reasoning_effort": "medium",
      "frequency_penalty": 0.25,
      "presence_penalty": 0.35,
      "context_length": 128000,
      "enable_thinking": true
    }
  ]
}
```

**参数说明**：
- `temperature: 0.7` - 较高创造性，生成丰富的文档内容
- `reasoning_effort: "medium"` - 确保文档逻辑性和准确性
- `thinking_budget: 3000` - 充分思考文档结构和内容组织
- `extra` 参数确保生成结构化、用户友好的文档

**ChatMock 启动参数**：
```bash
python3 chatmock.py serve --reasoning-effort medium --enable-web-search
```

### 5. 调试辅助配置

**适用场景**：错误诊断、问题排查、性能优化、代码审查
**优化目标**：精确分析、快速定位问题、提供解决方案

```json
{
  "oaicopilot.baseUrl": "http://127.0.0.1:8000/v1",
  "oaicopilot.models": [
    {
      "id": "gpt-5.1-codex",
      "owned_by": "chatmock",
      "configId": "debugging",
      "displayName": "?? Debugging Assistant",
      "temperature": 0.0,
      "top_p": 1.0,
      "max_tokens": 5120,
      "reasoning_effort": "high",
      "frequency_penalty": 0.0,
      "presence_penalty": 0.05,
      "context_length": 128000,
      "enable_thinking": true,
      "thinking_budget": 6000
    }
  ]
}
```

**参数说明**：
- `temperature: 0.0` - 零随机性，确保分析结果的一致性和准确性
- `top_p: 1.0` - 使用所有可能的 token，确保不遗漏重要信息
- `reasoning_effort: "high"` - 深度分析复杂问题
- `extra` 参数启用分析模式、逐步推理和错误模式识别

**ChatMock 启动参数**：
```bash
python3 chatmock.py serve --reasoning-effort high --enable-web-search
```

### 6. 任务计划配置

**适用场景**：项目规划、任务分解、时间管理、资源分配
**优化目标**：系统性思考、可行性分析、详细规划

```json
{
  "oaicopilot.baseUrl": "http://127.0.0.1:8000/v1",
  "oaicopilot.models": [
    {
      "id": "gpt-5.1",
      "owned_by": "chatmock",
      "configId": "task-planning",
      "displayName": "📋 Task Planning",
      "temperature": 0.35,
      "top_p": 0.93,
      "max_tokens": 7168,
      "reasoning_effort": "high",
      "frequency_penalty": 0.3,
      "presence_penalty": 0.25,
      "context_length": 128000,
      "enable_thinking": true,
      "thinking_budget": 6000
    }
  ]
}
```

**参数说明**：
- `temperature: 0.4` - 适度创造性，平衡创新和实用性
- `reasoning_effort: "high"` - 深度思考项目复杂性和依赖关系
- `thinking_budget: 3500` - 充分规划任务分解和时间安排
- `extra` 参数确保生成结构化的项目计划，包含时间估算和风险评估

**ChatMock 启动参数**：
```bash
python3 chatmock.py serve --reasoning-effort high --enable-web-search
```

## 多场景综合配置

### 完整的多场景配置示例

```json
{
  "oaicopilot.baseUrl": "http://127.0.0.1:8000/v1",
  "oaicopilot.models": [
    {
      "id": "gpt-5.1-codex-mini",
      "owned_by": "chatmock",
      "configId": "daily-coding",
      "displayName": "⚡ Daily Coding",
      "temperature": 0.1,
      "max_tokens": 1024,
      "reasoning_effort": "low",
      "frequency_penalty": 0.1,
      "presence_penalty": 0.1
    },
    {
      "id": "gpt-5.1-codex",
      "owned_by": "chatmock",
      "configId": "complex-implementation",
      "displayName": "🧠 Complex Implementation",
      "temperature": 0.2,
      "max_tokens": 4096,
      "reasoning_effort": "medium",
      "enable_thinking": true,
      "thinking_budget": 2000
    },
    {
      "id": "gpt-5.1",
      "owned_by": "chatmock",
      "configId": "architecture-design",
      "displayName": "🏗️ Architecture Design",
      "temperature": 0.3,
      "max_tokens": 8192,
      "reasoning_effort": "high",
      "enable_thinking": true,
      "thinking_budget": 4000
    },
    {
      "id": "gpt-5.1",
      "owned_by": "chatmock",
      "configId": "documentation",
      "displayName": "📚 Documentation",
      "temperature": 0.7,
      "max_tokens": 6144,
      "reasoning_effort": "medium",
      "enable_thinking": true,
      "thinking_budget": 3000
    },
    {
      "id": "gpt-5.1-codex",
      "owned_by": "chatmock",
      "configId": "debugging",
      "displayName": "🔍 Debugging Assistant",
      "temperature": 0.0,
      "max_tokens": 3072,
      "reasoning_effort": "high",
      "enable_thinking": true,
      "thinking_budget": 2500
    },
    {
      "id": "gpt-5.1",
      "owned_by": "chatmock",
      "configId": "task-planning",
      "displayName": "📋 Task Planning",
      "temperature": 0.4,
      "max_tokens": 5120,
      "reasoning_effort": "high",
      "enable_thinking": true,
      "thinking_budget": 3500
    }
  ]
}
```

## 环境特定配置

### 开发环境配置

```json
{
  "oaicopilot.baseUrl": "http://127.0.0.1:8000/v1",
  "oaicopilot.models": [
    {
      "id": "gpt-5.1-codex-mini",
      "owned_by": "chatmock",
      "configId": "dev-fast",
      "displayName": "⚡ Dev Fast",
      "temperature": 0.1,
      "max_tokens": 1024,
      "reasoning_effort": "low"
    },
    {
      "id": "gpt-5.1-codex",
      "owned_by": "chatmock",
      "configId": "dev-debug",
      "displayName": "🔧 Dev Debug",
      "temperature": 0.0,
      "max_tokens": 2048,
      "reasoning_effort": "medium"
    }
  ]
}
```

### 生产环境配置

```json
{
  "oaicopilot.baseUrl": "http://127.0.0.1:8000/v1",
  "oaicopilot.models": [
    {
      "id": "gpt-5.1",
      "owned_by": "chatmock",
      "configId": "prod-architecture",
      "displayName": "🏗️ Prod Architecture",
      "temperature": 0.2,
      "max_tokens": 8192,
      "reasoning_effort": "high",
      "enable_thinking": true,
      "thinking_budget": 4000
    },
    {
      "id": "gpt-5.1",
      "owned_by": "chatmock",
      "configId": "prod-documentation",
      "displayName": "📚 Prod Documentation",
      "temperature": 0.5,
      "max_tokens": 6144,
      "reasoning_effort": "medium"
    }
  ]
}
```

## 性能优化建议

### 根据工作负载动态选择

```json
{
  "oaicopilot.models": [
    {
      "id": "gpt-5.1-codex-mini",
      "owned_by": "chatmock",
      "configId": "lightweight",
      "displayName": "🪶 Lightweight",
      "temperature": 0.1,
      "max_tokens": 512,
      "reasoning_effort": "low"
    },
    {
      "id": "gpt-5.1-codex",
      "owned_by": "chatmock",
      "configId": "standard",
      "displayName": "⚖️ Standard",
      "temperature": 0.2,
      "max_tokens": 2048,
      "reasoning_effort": "medium"
    },
    {
      "id": "gpt-5.1",
      "owned_by": "chatmock",
      "configId": "heavyweight",
      "displayName": "🏋️ Heavyweight",
      "temperature": 0.3,
      "max_tokens": 4096,
      "reasoning_effort": "high",
      "enable_thinking": true,
      "thinking_budget": 3000
    }
  ]
}
```

### ChatMock 服务优化配置

```bash
# 开发环境 - 快速响应
python3 chatmock.py serve \
  --host 127.0.0.1 \
  --port 8000 \
  --reasoning-effort low \
  --max-connections 50 \
  --timeout 30

# 生产环境 - 高质量处理
python3 chatmock.py serve \
  --host 0.0.0.0 \
  --port 8000 \
  --reasoning-effort high \
  --enable-web-search \
  --max-connections 20 \
  --timeout 120

# 混合环境 - 平衡性能
python3 chatmock.py serve \
  --host 127.0.0.1 \
  --port 8000 \
  --reasoning-effort medium \
  --enable-web-search \
  --max-connections 30 \
  --timeout 60
```

## 高级配置选项

### 1. 推理努力配置

#### 在模型配置中设置推理努力
```json
{
  "oaicopilot.models": [
    {
      "id": "gpt-5.1",
      "owned_by": "chatmock",
      "configId": "high-reasoning",
      "reasoning_effort": "high"
    },
    {
      "id": "gpt-5.1",
      "owned_by": "chatmock",
      "configId": "low-reasoning",
      "reasoning_effort": "low"
    }
  ]
}
```

#### 推理努力级别说明
- `"high"` - 最高推理努力，适合复杂问题解决
- `"medium"` - 中等推理努力，平衡性能和质量
- `"low"` - 低推理努力，快速响应
- `"minimal"` - 最低推理努力，最快响应

### 2. 思维链配置

#### 启用/禁用思维链显示
```json
{
  "oaicopilot.models": [
    {
      "id": "gpt-5.1",
      "owned_by": "chatmock",
      "configId": "thinking-enabled",
      "enable_thinking": true,
      "thinking_budget": 4000
    },
    {
      "id": "gpt-5.1",
      "owned_by": "chatmock",
      "configId": "thinking-disabled",
      "enable_thinking": false
    }
  ]
}
```

### 3. 网络搜索功能

#### 启用网络搜索
```bash
# 启动 ChatMock 时启用网络搜索
python3 chatmock.py serve --enable-web-search
```

#### 在模型配置中控制网络搜索
```json
{
  "oaicopilot.models": [
    {
      "id": "gpt-5.1",
      "owned_by": "chatmock",
      "extra": {
        "responses_tools": [{"type": "web_search"}],
        "responses_tool_choice": "auto"
      }
    }
  ]
}
```

### 4. 自定义端口配置

#### 使用不同端口启动 ChatMock
```bash
python3 chatmock.py serve --port 8080
```

#### 更新配置中的 baseUrl
```json
{
  "oaicopilot.baseUrl": "http://127.0.0.1:8080/v1"
}
```

### 5. 多 Provider 配置

#### 配置多个 ChatMock 实例
```json
{
  "oaicopilot.models": [
    {
      "id": "gpt-5.1",
      "owned_by": "chatmock-local",
      "baseUrl": "http://127.0.0.1:8000/v1",
      "temperature": 0.7
    },
    {
      "id": "gpt-5.1",
      "owned_by": "chatmock-remote",
      "baseUrl": "http://remote-server:8000/v1",
      "temperature": 0.5
    }
  ]
}
```

#### 设置多个 API 密钥
1. 打开命令面板
2. 搜索 "OAICopilot: Set OAI Compatible Multi-Provider Apikey"
3. 分别为 `chatmock-local` 和 `chatmock-remote` 设置 API 密钥

## 模型参数详解

### 基础参数
- `id` (必需): 模型标识符，如 `"gpt-5.1"`
- `owned_by` (必需): Provider 标识符，如 `"chatmock"`
- `displayName`: 在 Copilot 界面中显示的名称
- `configId`: 配置ID，允许同一模型有多个配置
- `family`: 模型系列，默认为 `"oai-compatible"`

### 上下文和生成参数
- `context_length`: 模型支持的上下文长度，默认 128000
- `max_tokens`: 最大生成 token 数，范围 [1, context_length]
- `max_completion_tokens`: OpenAI 新标准参数
- `vision`: 是否支持视觉功能，默认 false

### 采样参数
- `temperature`: 采样温度，范围 [0, 2]，默认 0
- `top_p`: Top-p 采样值，范围 (0, 1]，默认 1
- `top_k`: Top-k 采样值，范围 [1, ∞)，可选
- `min_p`: 最小概率阈值，范围 [0, 1]，可选

### 惩罚参数
- `frequency_penalty`: 频率惩罚，范围 [-2, 2]，可选
- `presence_penalty`: 存在惩罚，范围 [-2, 2]，可选
- `repetition_penalty`: 重复惩罚，范围 (0, 2]，可选

### 推理和思维参数
- `enable_thinking`: 启用思维链显示
- `thinking_budget`: 思维链最大 token 数
- `reasoning_effort`: 推理努力级别 (xhigh/high/medium/low/minimal)
- `reasoning`: OpenRouter 推理配置
- `thinking`: Zai provider 思维配置

### 其他参数
- `baseUrl`: 模型特定的基础 URL
- `headers`: 自定义 HTTP 头
- `extra`: 额外的请求参数

## 工作区配置管理

### 工作区特定配置
在项目根目录创建 `.vscode/settings.json`：
```json
{
  "oaicopilot.baseUrl": "http://127.0.0.1:8000/v1",
  "oaicopilot.models": [
    {
      "id": "gpt-5.1-codex",
      "owned_by": "chatmock",
      "configId": "project-specific",
      "temperature": 0.2,
      "max_tokens": 4096
    }
  ]
}
```

### 全局默认配置
在 VS Code 用户设置中：
```json
{
  "oaicopilot.baseUrl": "http://127.0.0.1:8000/v1",
  "oaicopilot.models": [
    {
      "id": "gpt-5.1",
      "owned_by": "chatmock",
      "temperature": 0.7,
      "reasoning_effort": "medium"
    }
  ]
}
```

### 环境特定配置
创建不同环境的配置文件：
```json
// .vscode/settings.dev.json (开发环境)
{
  "oaicopilot.models": [
    {
      "id": "gpt-5.1-codex-mini",
      "owned_by": "chatmock",
      "reasoning_effort": "low"
    }
  ]
}

// .vscode/settings.prod.json (生产环境)
{
  "oaicopilot.models": [
    {
      "id": "gpt-5.1",
      "owned_by": "chatmock",
      "reasoning_effort": "high"
    }
  ]
}
```

## 故障排除

### 1. 连接问题

**检查 ChatMock 服务状态：**
```bash
# 检查服务是否运行
curl http://127.0.0.1:8000/health

# 检查端口占用
netstat -tlnp | grep :8000

# 查看 ChatMock 日志
python3 chatmock.py serve --verbose
```

**检查 OAI Compatible Provider 扩展状态：**
1. 在 VS Code 中查看扩展是否已启用
2. 检查扩展版本是否为最新
3. 重启 VS Code

**解决方案：**
- 确保 ChatMock 正在运行
- 检查 `oaicopilot.baseUrl` 配置是否正确
- 验证防火墙设置
- 重启 OAI Compatible Provider 扩展

### 2. API 密钥问题

**检查 API 密钥配置：**
1. 打开命令面板
2. 搜索 "OAICopilot: Set OAI Compatible Multi-Provider Apikey"
3. 确认 `chatmock` provider 的密钥已设置

**重新设置 API 密钥：**
1. 删除现有的 `chatmock` 密钥
2. 重新添加密钥：`key`
3. 重启 VS Code

### 3. 模型不显示问题

**检查模型配置：**
```bash
# 确认 ChatMock 支持的模型
curl http://127.0.0.1:8000/v1/models

# 检查 VS Code 配置中的模型列表
# 在设置中查看 oaicopilot.models 配置
```

**重新加载模型：**
1. 在 Copilot Chat 中点击模型选择器
2. 选择 "Manage Models..."
3. 刷新 OAI Compatible provider
4. 重新选择模型

### 4. 扩展兼容性问题

**检查 VS Code 版本：**
- 最低要求：VS Code 1.104.0 或更高

**检查扩展冲突：**
- 禁用其他 Copilot 相关扩展
- 确保 GitHub Copilot 扩展已正确安装

### 5. 常见错误及解决方案

**错误：Model not found**
- 检查模型 ID 拼写
- 确认模型在 ChatMock 支持列表中
- 验证 `configId` 是否唯一

**错误：Connection refused**
- 检查 ChatMock 服务状态
- 验证端口号和 URL 配置
- 检查网络连接

**错误：Authentication failed**
- 重新设置 API 密钥
- 检查 `owned_by` 字段是否正确
- 验证 ChatMock 登录状态

### 6. ChatMock 支持的模型列表
- `gpt-5` - 基础 GPT-5 模型
- `gpt-5.1` - GPT-5.1 模型
- `gpt-5-codex` - GPT-5 代码模型
- `gpt-5.1-codex` - GPT-5.1 代码模型
- `gpt-5.1-codex-mini` - 轻量级 GPT-5.1 代码模型
- `codex-mini` - 轻量级代码模型

## 测试验证

### 1. ChatMock 服务测试
```python
import requests
import json

def test_chatmock_service():
    base_url = "http://127.0.0.1:8000/v1"
    
    print("=== ChatMock 服务测试 ===")
    
    # 测试健康检查
    try:
        health = requests.get("http://127.0.0.1:8000/health")
        print(f"✓ 健康检查: {health.status_code}")
        if health.status_code == 200:
            print(f"  响应: {health.json()}")
    except Exception as e:
        print(f"✗ 健康检查失败: {e}")
        return
    
    # 测试模型列表
    try:
        models = requests.get(f"{base_url}/models")
        print(f"✓ 模型列表: {models.status_code}")
        if models.status_code == 200:
            available_models = [m['id'] for m in models.json()['data']]
            print(f"  可用模型: {available_models}")
            
            # 检查 Copilot 相关模型
            copilot_models = ["gpt-5.1", "gpt-5.1-codex", "gpt-5.1-codex-mini"]
            for model in copilot_models:
                if model in available_models:
                    print(f"  ✓ {model} 可用")
                else:
                    print(f"  ✗ {model} 不可用")
    except Exception as e:
        print(f"✗ 模型列表测试失败: {e}")
    
    # 测试聊天完成
    try:
        chat_data = {
            "model": "gpt-5.1",
            "messages": [{"role": "user", "content": "Hello, ChatMock!"}],
            "reasoning": {"effort": "low"}
        }
        
        response = requests.post(
            f"{base_url}/chat/completions",
            headers={
                "Authorization": "Bearer key",
                "Content-Type": "application/json"
            },
            json=chat_data
        )
        
        print(f"✓ 聊天完成: {response.status_code}")
        if response.status_code == 200:
            result = response.json()
            print(f"  响应: {result['choices'][0]['message']['content'][:50]}...")
    except Exception as e:
        print(f"✗ 聊天完成测试失败: {e}")

if __name__ == "__main__":
    test_chatmock_service()
```

### 2. OAI Compatible Provider 扩展测试

#### 扩展状态检查
1. 打开 VS Code 扩展面板 (`Ctrl/Cmd + Shift + X`)
2. 搜索 "OAI Compatible Provider for Copilot"
3. 确认扩展已启用且为最新版本

#### 配置验证
1. 打开 VS Code 设置 (`Ctrl/Cmd + ,`)
2. 搜索 `oaicopilot`
3. 确认配置正确：
   - `oaicopilot.baseUrl` 设置为 `http://127.0.0.1:8000/v1`
   - `oaicopilot.models` 包含正确的模型配置

#### API 密钥验证
1. 打开命令面板 (`Ctrl/Cmd + Shift + P`)
2. 搜索 "OAICopilot: Set OAI Compatible Multi-Provider Apikey"
3. 确认 `chatmock` provider 的密钥已设置

### 3. Copilot Chat 集成测试

#### 模型选择测试
1. 打开 GitHub Copilot Chat (`Ctrl/Cmd + Alt + I`)
2. 点击模型选择器
3. 选择 "Manage Models..."
4. 确认 "OAI Compatible" provider 出现
5. 确认配置的模型出现在列表中

#### 对话测试
1. 在 Copilot Chat 中选择 ChatMock 模型
2. 发送测试消息："Hello, can you help me with Python coding?"
3. 验证响应质量和速度
4. 测试不同配置的模型（如 high-reasoning vs low-reasoning）

#### 代码生成测试
1. 创建新的 Python 文件
2. 在 Copilot Chat 中请求代码生成
3. 验证生成的代码质量和准确性
4. 测试代码补全功能

### 4. 性能基准测试
```python
import time
import requests

def benchmark_chatmock():
    base_url = "http://127.0.0.1:8000/v1"
    
    test_prompts = [
        "Write a Python function to calculate fibonacci numbers",
        "Explain the concept of recursion in programming",
        "Create a simple REST API using Flask"
    ]
    
    models = ["gpt-5.1-codex-mini", "gpt-5.1-codex", "gpt-5.1"]
    
    print("=== 性能基准测试 ===")
    
    for model in models:
        print(f"\n测试模型: {model}")
        for prompt in test_prompts:
            start_time = time.time()
            
            try:
                response = requests.post(
                    f"{base_url}/chat/completions",
                    headers={
                        "Authorization": "Bearer key",
                        "Content-Type": "application/json"
                    },
                    json={
                        "model": model,
                        "messages": [{"role": "user", "content": prompt}],
                        "reasoning": {"effort": "medium"}
                    }
                )
                
                end_time = time.time()
                
                if response.status_code == 200:
                    result = response.json()
                    content = result['choices'][0]['message']['content']
                    print(f"  ✓ {prompt[:30]}... - {end_time - start_time:.2f}s - {len(content)} chars")
                else:
                    print(f"  ✗ {prompt[:30]}... - 失败: {response.status_code}")
                    
            except Exception as e:
                print(f"  ✗ {prompt[:30]}... - 错误: {e}")

if __name__ == "__main__":
    benchmark_chatmock()
```

## 性能优化建议

### 1. 模型选择策略

#### 根据使用场景选择模型
- **快速原型开发**：使用 `gpt-5.1-codex-mini` + `reasoning_effort: "low"`
- **日常编码**：使用 `gpt-5.1-codex` + `reasoning_effort: "medium"`
- **复杂算法**：使用 `gpt-5.1-codex` + `reasoning_effort: "high"`
- **架构设计**：使用 `gpt-5.1` + `reasoning_effort: "high"`
- **代码审查**：使用 `gpt-5.1` + `temperature: 0.2`

#### 模型切换配置
```json
{
  "oaicopilot.models": [
    {
      "id": "gpt-5.1-codex-mini",
      "owned_by": "chatmock",
      "configId": "fast",
      "displayName": "⚡ Fast Coding",
      "reasoning_effort": "low",
      "max_tokens": 2048
    },
    {
      "id": "gpt-5.1-codex",
      "owned_by": "chatmock",
      "configId": "balanced",
      "displayName": "⚖️ Balanced Coding",
      "reasoning_effort": "medium",
      "max_tokens": 4096
    },
    {
      "id": "gpt-5.1",
      "owned_by": "chatmock",
      "configId": "deep",
      "displayName": "🧠 Deep Reasoning",
      "reasoning_effort": "high",
      "max_tokens": 8192
    }
  ]
}
```

### 2. ChatMock 服务优化

#### 启动参数优化
```bash
# 高性能配置
python3 chatmock.py serve \
  --host 127.0.0.1 \
  --port 8000 \
  --max-connections 20 \
  --timeout 60 \
  --reasoning-effort medium

# 开发环境配置
python3 chatmock.py serve \
  --host 127.0.0.1 \
  --port 8000 \
  --reasoning-effort low \
  --enable-web-search

# 生产环境配置
python3 chatmock.py serve \
  --host 0.0.0.0 \
  --port 8000 \
  --max-connections 50 \
  --timeout 120 \
  --reasoning-effort high
```

#### 系统资源优化
```bash
# 监控资源使用
htop  # 监控 CPU 和内存
iotop # 监控 I/O

# 调整 Python 进程优先级
renice -10 $(pgrep -f chatmock.py)

# 使用 systemd 管理（生产环境）
sudo systemctl enable chatmock
sudo systemctl start chatmock
```

### 3. 网络优化

#### 本地网络优化
```bash
# 绑定到 localhost 减少网络开销
python3 chatmock.py serve --host 127.0.0.1

# 使用更快的端口（如果可用）
python3 chatmock.py serve --port 8001

# 启用 HTTP/2（如果支持）
python3 chatmock.py serve --enable-http2
```

#### 防火墙配置
```bash
# 仅允许本地访问
sudo ufw allow from 127.0.0.1 to any port 8000

# 或者允许特定子网
sudo ufw allow from 192.168.1.0/24 to any port 8000
```

### 4. 缓存和预加载

#### 启用缓存（如果支持）
```bash
python3 chatmock.py serve --enable-cache --cache-size 1GB
```

#### 预加载常用模型
```json
{
  "oaicopilot.models": [
    {
      "id": "gpt-5.1-codex",
      "owned_by": "chatmock",
      "configId": "preloaded",
      "extra": {
        "preload": true,
        "warmup_prompts": ["def hello():", "class Example:"]
      }
    }
  ]
}
```

## 常见问题解答

### Q: OAI Compatible Provider 扩展无法找到 ChatMock 模型？
A: 检查以下几点：
1. 确认 ChatMock 服务正在运行且可访问
2. 检查 `oaicopilot.baseUrl` 配置是否正确
3. 验证 `oaicopilot.models` 中的模型 ID 是否在 ChatMock 支持列表中
4. 重新加载扩展或重启 VS Code

### Q: 模型选择器中显示的模型名称不正确？
A: 检查 `displayName` 配置：
```json
{
  "id": "gpt-5.1",
  "owned_by": "chatmock",
  "displayName": "ChatMock GPT-5.1 High Reasoning",
  "configId": "high"
}
```

### Q: 如何在团队中共享配置？
A: 创建工作区配置文件：
1. 在项目根目录创建 `.vscode/settings.json`
2. 将 `oaicopilot` 配置添加到文件中
3. 将文件提交到版本控制
4. 团队成员拉取后自动获得配置

### Q: 如何处理 API 限流？
A: 优化建议：
1. 使用 `max_tokens` 限制响应长度
2. 选择合适的 `reasoning_effort` 级别
3. 在高负载时使用轻量级模型
4. 考虑部署多个 ChatMock 实例

### Q: Copilot Chat 中的响应很慢？
A: 排查步骤：
1. 检查 ChatMock 服务响应时间
2. 验证网络连接质量
3. 降低 `reasoning_effort` 级别
4. 减少 `max_tokens` 设置
5. 使用更轻量的模型

### Q: 如何启用调试模式？
A: 启用详细日志：
```bash
# ChatMock 调试模式
python3 chatmock.py serve --verbose --debug

# VS Code 扩展调试
# 在 VS Code 设置中启用开发者模式
# 查看扩展开发者工具的控制台输出
```

### Q: 如何备份和恢复配置？
A: 备份方法：
```bash
# 导出 VS Code 设置
code --export-extensions > extensions.txt
cp ~/.config/Code/User/settings.json settings-backup.json

# 导入配置
code --install-extension extensions.txt
cp settings-backup.json ~/.config/Code/User/settings.json
```

## 高级使用技巧

### 1. 条件模型选择
根据文件类型自动选择模型：
```json
{
  "oaicopilot.models": [
    {
      "id": "gpt-5.1-codex",
      "owned_by": "chatmock",
      "configId": "python",
      "family": "python"
    },
    {
      "id": "gpt-5.1",
      "owned_by": "chatmock",
      "configId": "documentation",
      "family": "documentation"
    }
  ]
}
```

### 2. 动态参数调整
根据时间或工作负载调整参数：
```json
{
  "oaicopilot.models": [
    {
      "id": "gpt-5.1-codex",
      "owned_by": "chatmock",
      "configId": "work-hours",
      "temperature": 0.1,
      "reasoning_effort": "high"
    },
    {
      "id": "gpt-5.1-codex-mini",
      "owned_by": "chatmock",
      "configId": "after-hours",
      "temperature": 0.3,
      "reasoning_effort": "low"
    }
  ]
}
```

### 3. 集成外部工具
通过 `extra` 参数集成外部服务：
```json
{
  "oaicopilot.models": [
    {
      "id": "gpt-5.1",
      "owned_by": "chatmock",
      "extra": {
        "responses_tools": [
          {"type": "web_search"},
          {"type": "code_execution"}
        ],
        "responses_tool_choice": "auto"
      }
    }
  ]
}
```

## 总结

通过本指南，您已经掌握了如何将 ChatMock 与 OAI Compatible Provider for Copilot 扩展集成，享受 GPT-5.1 系列模型的强大功能。关键要点：

1. **正确的配置格式**：使用 `oaicopilot.baseUrl` 和 `oaicopilot.models`
2. **灵活的模型配置**：支持多配置、多 provider 和高级参数
3. **性能优化**：根据使用场景选择合适的模型和参数
4. **故障排除**：掌握常见问题的诊断和解决方法
5. **高级功能**：利用思维链、推理努力等高级特性

现在您可以在 GitHub Copilot Chat 中使用 ChatMock 的强大功能，享受更智能的编程助手体验！

## 相关资源

- [OAI Compatible Provider for Copilot 扩展页面](https://marketplace.visualstudio.com/items?itemName=johnny-zhao.oai-compatible-copilot)
- [ChatMock 项目文档](./README.md)
- [GPT-5.1 支持说明](./GPT5.1_SUPPORT_SUMMARY.md)
- [快速配置指南](./QUICK_OAI_SETUP.md)
- [集成测试脚本](./test_oai_integration.py)
