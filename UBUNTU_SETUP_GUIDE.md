# ChatMock Ubuntu 使用指南

## 系统要求
- Ubuntu 18.04+ 
- Python 3.8+
- pip3
- git

## 安装步骤

### 1. 安装系统依赖
```bash
# 更新包管理器
sudo apt update

# 安装 Python 和 pip（如果未安装）
sudo apt install python3 python3-pip python3-venv

# 安装 git（如果未安装）
sudo apt install git
```

### 2. 克隆项目
```bash
git clone https://github.com/RayBytes/ChatMock.git
cd ChatMock
```

### 3. 安装 Python 依赖
```bash
# 安装兼容的依赖版本
pip3 install flask==3.0.3 requests==2.31.0 click==8.1.7 blinker==1.8.2 certifi urllib3 idna itsdangerous jinja2 markupsafe werkzeug

# 或者使用 requirements.txt（已修复兼容性）
pip3 install -r requirements.txt
```

## 使用方法

### 1. 登录 ChatGPT 账户
```bash
# 启动登录流程（会自动打开浏览器）
python3 chatmock.py login

# 如果无法自动打开浏览器
python3 chatmock.py login --no-browser
```

### 2. 查看账户信息
```bash
# 查看当前登录状态和使用限制
python3 chatmock.py info

# 以 JSON 格式查看认证信息
python3 chatmock.py info --json
```

### 3. 启动服务器
```bash
# 启动默认服务器（127.0.0.1:8000）
python3 chatmock.py serve

# 指定主机和端口
python3 chatmock.py serve --host 0.0.0.0 --port 8080

# 启用详细日志
python3 chatmock.py serve --verbose

# 设置推理努力程度
python3 chatmock.py serve --reasoning-effort high

# 暴露推理模型变体
python3 chatmock.py serve --expose-reasoning-models

# 启用网络搜索
python3 chatmock.py serve --enable-web-search
```

## 测试验证

### 1. 运行测试脚本
```bash
# 在一个终端启动服务器
python3 chatmock.py serve &

# 在另一个终端运行测试
python3 test_chatmock.py
```

### 2. 手动测试 API

#### 健康检查
```bash
curl http://127.0.0.1:8000/health
```

#### 获取模型列表
```bash
curl http://127.0.0.1:8000/v1/models
```

#### 聊天完成测试
```bash
curl http://127.0.0.1:8000/v1/chat/completions \
  -H "Authorization: Bearer key" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-5",
    "messages": [{"role":"user","content":"hello world"}]
  }'
```

## 环境变量配置

### 设置客户端 ID（如果需要）
```bash
export CHATGPT_LOCAL_CLIENT_ID="your_client_id"
```

### 其他常用环境变量
```bash
# 设置调试模型
export CHATGPT_LOCAL_DEBUG_MODEL="gpt-5"

# 设置推理努力
export CHATGPT_LOCAL_REASONING_EFFORT="high"

# 设置推理摘要
export CHATGPT_LOCAL_REASONING_SUMMARY="detailed"

# 启用网络搜索
export CHATGPT_LOCAL_ENABLE_WEB_SEARCH="true"
```

## 常见问题解决

### 1. 依赖版本冲突
如果遇到依赖版本问题，使用以下命令安装兼容版本：
```bash
pip3 install flask==3.0.3 requests==2.31.0 click==8.1.7 blinker==1.8.2
```

### 2. 端口被占用
如果端口 8000 被占用，使用其他端口：
```bash
python3 chatmock.py serve --port 8080
```

### 3. 浏览器无法打开
如果登录时浏览器无法自动打开，手动访问显示的 URL，或使用：
```bash
python3 chatmock.py login --no-browser
```

### 4. 权限问题
如果遇到权限问题，确保 Python 包安装在用户目录：
```bash
pip3 install --user -r requirements.txt
```

## 支持的模型

### 通用模型
- `gpt-5` - 主要的 GPT-5 模型
  - 推理支持: minimal, low, medium, high
- `gpt-5.1` - 新的 GPT-5.1 模型（性能更强）
  - 推理支持: low, medium, high

### 代码专用模型
- `gpt-5-codex` - 代码专用的 GPT-5 模型
  - 推理支持: low, medium, high
- `gpt-5.1-codex` - 新的代码专用 GPT-5.1 模型
  - 推理支持: low, medium, high
- `gpt-5.1-codex-mini` - 新的轻量级 GPT-5.1 代码模型
  - 推理支持: medium, high
- `codex-mini` - 轻量级代码模型
  - 推理支持: 无

## 功能特性
- ✅ OpenAI API 兼容
- ✅ Ollama API 兼容
- ✅ 工具/函数调用
- ✅ 视觉/图像理解
- ✅ 思考摘要
- ✅ 网络搜索工具
- ✅ 推理努力程度配置

## 注意事项
1. 需要付费的 ChatGPT 账户
2. 确保网络连接稳定
3. 注意使用限制和配额
4. 遵守 OpenAI 的使用条款

## 获取帮助
```bash
# 查看命令帮助
python3 chatmock.py --help
python3 chatmock.py serve --help
python3 chatmock.py login --help
```