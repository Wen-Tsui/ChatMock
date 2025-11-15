# OAI Compatible Provider 配置 ChatMock 详细教程

## 概述

ChatMock 提供了完整的 OpenAI API 兼容接口，可以与任何支持 OAI Compatible Provider 的应用程序集成。本教程将指导您如何配置各种常见的 OAI Compatible Provider 来使用 ChatMock。

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

## 通用配置参数

无论使用哪种 OAI Compatible Provider，通常需要以下配置：

### 基础连接配置
- **API Base URL**: `http://127.0.0.1:8000/v1`
- **API Key**: `key` (ChatMock 会忽略此值，但某些客户端需要)
- **Model**: 根据需求选择支持的模型

### 支持的模型
- `gpt-5` - 主要的 GPT-5 模型
- `gpt-5.1` - 新的 GPT-5.1 模型
- `gpt-5-codex` - 代码专用 GPT-5 模型
- `gpt-5.1-codex` - 新的代码专用 GPT-5.1 模型
- `gpt-5.1-codex-mini` - 轻量级 GPT-5.1 代码模型
- `codex-mini` - 轻量级代码模型

## 常见 OAI Compatible Provider 配置

### 1. Cursor IDE

**配置步骤：**
1. 打开 Cursor 设置 (Ctrl/Cmd + ,)
2. 搜索 "Model" 或 "API"
3. 配置以下参数：
   ```
   API Base URL: http://127.0.0.1:8000/v1
   API Key: key
   Model: gpt-5.1
   ```

**JSON 配置文件：**
```json
{
  "openai": {
    "baseURL": "http://127.0.0.1:8000/v1",
    "apiKey": "key",
    "model": "gpt-5.1"
  }
}
```

### 2. Continue.dev

**配置步骤：**
1. 打开 Continue 设置
2. 添加或修改配置文件 `~/.continue/config.json`
3. 配置如下：

```json
{
  "models": [
    {
      "title": "ChatMock GPT-5.1",
      "provider": "openai",
      "model": "gpt-5.1",
      "apiBase": "http://127.0.0.1:8000/v1",
      "apiKey": "key"
    }
  ],
  "tabAutocompleteModel": {
    "title": "ChatMock GPT-5.1-Codex",
    "provider": "openai", 
    "model": "gpt-5.1-codex",
    "apiBase": "http://127.0.0.1:8000/v1",
    "apiKey": "key"
  }
}
```

### 3. VS Code 插件 (如 CodeGPT, GitHub Copilot 替代)

**配置步骤：**
1. 安装支持 OAI Compatible 的 VS Code 插件
2. 在插件设置中配置：
   ```
   OpenAI API Base URL: http://127.0.0.1:8000/v1
   OpenAI API Key: key
   Default Model: gpt-5.1
   ```

**settings.json 配置：**
```json
{
  "codegpt.apiBaseUrl": "http://127.0.0.1:8000/v1",
  "codegpt.apiKey": "key",
  "codegpt.model": "gpt-5.1"
}
```

### 4. Web 应用 (ChatBot UI, Open WebUI 等)

**ChatBot UI 配置：**
1. 访问 ChatBot UI 设置页面
2. 配置自定义 API：
   ```
   API Base URL: http://127.0.0.1:8000/v1
   API Key: key
   Model: gpt-5.1
   ```

**Open WebUI 配置：**
```yaml
# docker-compose.yml 环境变量
environment:
  - OPENAI_API_BASE_URL=http://127.0.0.1:8000/v1
  - OPENAI_API_KEY=key
  - DEFAULT_MODELS=gpt-5.1,gpt-5.1-codex
```

### 5. Python 应用配置

**使用 OpenAI 库：**
```python
from openai import OpenAI

client = OpenAI(
    base_url="http://127.0.0.1:8000/v1",
    api_key="key"  # ChatMock 会忽略此值
)

response = client.chat.completions.create(
    model="gpt-5.1",
    messages=[{"role": "user", "content": "Hello!"}]
)
print(response.choices[0].message.content)
```

**环境变量配置：**
```bash
export OPENAI_BASE_URL=http://127.0.0.1:8000/v1
export OPENAI_API_KEY=key
```

## 高级配置选项

### 1. 推理努力配置

对于支持推理的模型，可以指定推理努力级别：

```python
# Python 示例
response = client.chat.completions.create(
    model="gpt-5.1",
    messages=[{"role": "user", "content": "Complex problem"}],
    reasoning={"effort": "high"}  # low, medium, high
)
```

```bash
# 启动 ChatMock 时设置默认推理努力
python3 chatmock.py serve --reasoning-effort high
```

### 2. 网络搜索工具

启用网络搜索功能：

```bash
# 启动时启用
python3 chatmock.py serve --enable-web-search
```

```python
# API 调用时启用
response = client.chat.completions.create(
    model="gpt-5.1",
    messages=[{"role": "user", "content": "What's the latest news?"}],
    responses_tools=[{"type": "web_search"}],
    responses_tool_choice="auto"
)
```

## 故障排除

### 1. 连接问题

**检查 ChatMock 服务状态：**
```bash
# 检查服务是否运行
curl http://127.0.0.1:8000/health

# 检查端口占用
netstat -tlnp | grep :8000
```

### 2. 认证问题

**检查 ChatMock 登录状态：**
```bash
python3 chatmock.py info
```

**重新登录：**
```bash
python3 chatmock.py login
```

### 3. 常见错误及解决方案

**错误：Connection refused**
- 确保 ChatMock 服务正在运行
- 检查端口号是否正确
- 验证防火墙设置

**错误：Model not found**
- 检查模型名称拼写
- 确认模型在可用列表中
- 验证 ChatGPT 账户权限

**错误：Authentication failed**
- 重新运行 `python3 chatmock.py login`
- 检查 ChatGPT 账户状态
- 确认是付费账户

## 测试验证

### 完整测试脚本

```python
import requests
import json

def test_chatmock_integration():
    base_url = "http://127.0.0.1:8000/v1"
    
    # 测试健康检查
    health = requests.get("http://127.0.0.1:8000/health")
    print(f"Health check: {health.status_code}")
    
    # 测试模型列表
    models = requests.get(f"{base_url}/models")
    print(f"Models: {models.status_code}")
    if models.status_code == 200:
        available_models = [m['id'] for m in models.json()['data']]
        print(f"Available models: {available_models}")
    
    # 测试聊天完成
    chat_data = {
        "model": "gpt-5.1",
        "messages": [{"role": "user", "content": "Hello, ChatMock!"}]
    }
    
    response = requests.post(
        f"{base_url}/chat/completions",
        headers={
            "Authorization": "Bearer key",
            "Content-Type": "application/json"
        },
        json=chat_data
    )
    
    print(f"Chat completion: {response.status_code}")
    if response.status_code == 200:
        result = response.json()
        print(f"Response: {result['choices'][0]['message']['content']}")

if __name__ == "__main__":
    test_chatmock_integration()
```

## 总结

通过以上配置，您可以将 ChatMock 与任何支持 OAI Compatible Provider 的应用程序集成。关键配置要点：

1. **Base URL**: `http://127.0.0.1:8000/v1`
2. **API Key**: `key` (占位符)
3. **模型选择**: 根据需求选择合适的 GPT-5.1 系列模型
4. **高级功能**: 根据需要启用推理、网络搜索等功能

如遇到问题，请参考故障排除部分或查看 ChatMock 日志输出。