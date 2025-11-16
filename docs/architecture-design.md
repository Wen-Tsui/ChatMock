# ChatMock 架构设计

## 1. 总体概览

ChatMock 是一个基于 Flask 的轻量级 "OpenAI 接口代理"，通过本地登录 ChatGPT 账号，将标准 OpenAI API 请求（/v1/chat/completions、/v1/completions 等）转换为 ChatGPT Responses API 调用，并将 SSE 流式结果再转换回 OpenAI 兼容格式返回。

其核心目标：
- **接口兼容**：对前端或其他服务暴露与 OpenAI 官方尽量一致的 HTTP 接口和 JSON 结构。
- **本地代理**：在本地持有 ChatGPT OAuth 凭据，统一转发到 ChatGPT Responses API。
- **可观测性与扩展**：对请求/响应进行必要的转换、日志和限流控制，并支持 reasoning、web_search 等高级能力。

### 1.1 高层组件图

```mermaid
flowchart LR
    Client["客户端 / SDK / 工具\n(调用 OpenAI 兼容接口)"]
    subgraph ChatMock[ChatMock 服务]
        CLI["chatmock.py CLI / gui.py"]
        WS["Flask Web Server\n(app.py)"]
        RO["OpenAI 路由\n(routes_openai.py)"]
        ROL["Ollama 路由\n(routes_ollama.py)"]
        UP["上游请求封装\n(upstream.py)"]
        RSN["Reasoning 处理\n(reasoning.py)"]
        SES["会话与缓存\n(session.py)"]
        LIM["限流 / 配额\n(limits.py)"]
        CFG["配置与指令\n(config.py)"]
        UTL["工具函数与 OAuth\n(utils.py, oauth.py, models.py)"]
    end

    ChatGPT["ChatGPT Responses API\n(OpenAI 上游)"]

    Client -->|HTTP /v1/*| WS
    WS --> RO
    WS --> ROL
    RO -->|构造输入/指令\n附加 reasoning / tools| RSN
    RO --> UP
    ROL --> UP
    RSN --> UP
    SES --> UP
    UP -->|HTTPS POST /responses| ChatGPT
    ChatGPT --> UP
    UP --> RO
    RO -->|OpenAI 兼容 JSON / SSE| Client

    RO --> LIM
    RO --> CFG
    UP --> UTL
```

## 2. 请求与数据流

### 2.1 /v1/chat/completions 数据流

```mermaid
sequenceDiagram
    participant C as Client
    participant F as Flask(app.py)
    participant O as routes_openai.chat_completions
    participant U as upstream.start_upstream_request
    participant S as ChatGPT Responses API

    C->>F: POST /v1/chat/completions (JSON)
    F->>O: 解析请求, 进入路由
    O->>O: 校验 JSON / messages
    O->>O: 归一化 model (normalize_model_name)
    O->>O: messages 转换为 input_items\n(convert_chat_messages_to_responses_input)
    O->>O: 构建 reasoning 参数\n(build_reasoning_param / extract_reasoning_from_model_name)
    O->>U: start_upstream_request(model, input_items, instructions, tools,...)
    U->>UTL: get_effective_chatgpt_auth -> 读取/刷新 OAuth
    U->>SES: ensure_session_id -> 生成/复用 session_id
    U->>S: POST /responses (stream=True)
    S-->>U: SSE events (response.output_text.delta 等)
    U-->>O: 返回流式 Response 对象
    O->>O: 解析 SSE 行, 累积 full_text / reasoning / tool_calls
    alt stream == true
        O-->>C: SSE text/event-stream\n(sse_translate_chat)
    else 非流式
        O-->>C: JSON chat.completion 对象\n(含 choices, usage)
    end
```

### 2.2 /v1/completions 数据流

```mermaid
sequenceDiagram
    participant C as Client
    participant F as Flask
    participant O as routes_openai.completions
    participant U as upstream
    participant S as ChatGPT

    C->>F: POST /v1/completions
    F->>O: 进入 completions 路由
    O->>O: 将 prompt 组装为 messages
    O->>O: 转换为 input_items
    O->>U: start_upstream_request(...)
    U->>S: POST /responses (stream=True)
    S-->>U: SSE events
    alt stream == true
        O-->>C: SSE 文本流\n(sse_translate_text)
    else
        O-->>C: JSON text completion 对象
    end
```

### 2.3 Responses SSE 事件到 OpenAI 格式的映射

`utils.sse_translate_chat` / `utils.sse_translate_text` / `routes_openai.chat_completions` 中完成以下映射：
- `response.output_text.delta` → OpenAI `choices[].delta.content` 或最终 `message.content`。
- `response.reasoning_summary_text.delta` / `response.reasoning_text.delta` → 根据 `reasoning_compat` 注入到思维标签或自定义字段。
- `response.output_item.done` + `type == function_call` → OpenAI `tool_calls` 或 `function_call` 结构。
- `response.failed` / `response.completed` → 控制 SSE 结束与错误返回。

## 3. 核心模块设计

### 3.1 应用入口与配置

- `chatmock/app.py`
  - **职责**：
    - 构建 Flask 应用实例。
    - 装载运行时配置（verbose、reasoning_*、debug_model、DEFAULT_WEB_SEARCH 等）。
    - 注册路由蓝图 `openai_bp`、`ollama_bp`。
    - 提供 `/` 和 `/health` 健康检查。
    - 在 `after_request` 中附加统一的 CORS 头（通过 `build_cors_headers`）。
  - **关键点**：
    - 所有业务逻辑都在蓝图内部；`create_app` 只做组合和配置注入。

- `chatmock/config.py`
  - **职责**：
    - 定义 `BASE_INSTRUCTIONS` 和 `GPT5_CODEX_INSTRUCTIONS` 等系统级提示词，
      在 `_instructions_for_model` 中根据模型选择不同的系统指令。
    - 持有上游 API 地址 `CHATGPT_RESPONSES_URL`、OAuth 配置、CLIENT_ID 等常量。

- `chatmock/cli.py`、`chatmock.py`、`gui.py`
  - **职责**：
    - 命令行/GUI 启动入口，调用 `create_app` 启动 HTTP 服务。
    - 提供 `login` 等命令，完成本地 OAuth 授权并写入 `auth.json`。

### 3.2 OpenAI 兼容路由层

- `chatmock/routes_openai.py`
  - **主要路由**：
    - `POST /v1/chat/completions` → `chat_completions`
    - `POST /v1/completions` → `completions`
  - **职责与处理流程（chat_completions）**：
    - **请求解析与校验**：
      - 从 `request.get_data` 读取原始 JSON 字符串，
        包含容错处理（换行、回车清洗后再次尝试解析）。
      - 统一将 `prompt` / `input` 转为 `messages` 列表，对缺失字段进行合理默认。
      - 若存在 `role == system` 的 message，将其内容移入首条 user message，以更好适配 Responses API。
    - **Streaming 与 usage 控制**：
      - 支持 `stream` 和 `stream_options.include_usage`，在 SSE 事件中聚合 usage，最终附加到响应。
    - **Tool / web_search 支持**：
      - `convert_tools_chat_to_responses` 转换 OpenAI tools。
      - `responses_tools` / `responses_tool_choice` 解析 web_search 等扩展工具，并限制 payload 大小。
      - 若上游拒绝 tools（包含 web_search），自动 fallback 到仅基础 tools + BASE_INSTRUCTIONS 的请求。
    - **Reasoning 支持**：
      - 从模型名提取 reasoning 维度（如 `gpt-5.1-codex-high`），再与 payload 中的 `reasoning` 字段合并。
      - 构造 `reasoning_param` 传入 `start_upstream_request`。
    - **SSE 解析与重组**：
      - 从 Responses SSE 中抽取 `full_text`、`reasoning_summary_text`、`reasoning_full_text`、`tool_calls`、`usage` 等。
      - 若非流式，将这些字段封装为 OpenAI `chat.completion` JSON 对象返回。
      - 将 reasoning 文本通过 `apply_reasoning_to_message` 注入到最终 `message`。

  - **职责与处理流程（completions）**：
    - 兼容传统 text completion 调用，将 `prompt` 折叠/拼接后转换成单一 user message。
    - 转换为 Responses `input_items` 后调用 `start_upstream_request`。
    - 使用 `sse_translate_text`/自定义解析聚合 SSE 文本并返回 OpenAI `text completion`。

### 3.3 Ollama 路由层

- `chatmock/routes_ollama.py`
  - **职责**：
    - 暴露兼容 Ollama 的 HTTP 接口，将请求转为上游模型调用或本地推理（视实现而定）。
    - 与 `routes_openai` 类似，负责解析请求、构造上游输入、以 SSE 或非流式形式返回。

### 3.4 上游访问与会话管理

- `chatmock/upstream.py`
  - **normalize_model_name(name, debug_model)**：
    - 处理 `gpt5` / `gpt-5-latest` / `gpt5.1-codex-high` 等别名与后缀（reasoning effort 形如 `-high`）。
    - 返回标准化模型名 `gpt-5`、`gpt-5.1`、`gpt-5-codex` 等。
  - **start_upstream_request(...)**：
    - 使用 `get_effective_chatgpt_auth` 获取 access_token、account_id，若缺失则返回 401，提示需要 `python3 chatmock.py login`。
    - 调用 `ensure_session_id` 生成/复用会话 ID（用于 prompt cache key 与 header `session_id`）。
    - 构造 Responses API 请求体：
      - `model`、`instructions`、`input`、`tools`、`tool_choice`、`parallel_tool_calls`、`store`(false)、`stream`(true)、`prompt_cache_key` 等。
      - 若启用 reasoning，则设置 `include=["reasoning.encrypted_content"]` 与 `responses_payload["reasoning"]`。
    - 使用 `requests.post(..., stream=True)` 连接上游，失败时包装为统一 JSON 错误并附加 CORS 头。
    - 在 `upstream` Response 对象上挂载 `_chatmock_request_ctx` 以便后续调试/日志。

- `chatmock/session.py`
  - **canonicalize_prefix(instructions, input_items)**：
    - 提取稳定的前缀（系统指令 + 第一条 user message 内容），并进行 JSON 规范化，以便生成指纹。
  - **ensure_session_id(...)**：
    - 若客户端在 header 中提供 `X-Session-Id` 或 `session_id`，则直接使用。
    - 否则根据规范化前缀计算 SHA256 指纹，维护一个有限大小的 LRU 字典 `_FINGERPRINT_TO_UUID`，为相同前缀复用 UUID 型 session_id。
    - 该 session_id 同时用作 Responses 请求体中的 `prompt_cache_key`。

### 3.5 工具函数与 OAuth 支撑

- `chatmock/utils.py`
  - **认证与配置存储**：
    - `get_home_dir` / `read_auth_file` / `write_auth_file`：读写 `~/.chatgpt-local/auth.json` 或 `~/.codex/auth.json`。
    - `load_chatgpt_tokens`：在必要时自动刷新 access_token，并持久化更新后的 tokens。
  - **OAuth 辅助**：
    - `generate_pkce`：生成 PKCE code_verifier/code_challenge。
  - **消息/工具转换**：
    - `convert_chat_messages_to_responses_input`：
      - 过滤 system、tool、assistant tool_calls 等不同角色。
      - 将 OpenAI `messages` 转为 Responses 的 `input_items`，支持文本与多模态图片（`input_image`）。
    - `convert_tools_chat_to_responses`：
      - 将 OpenAI 风格 tools 描述转换为 Responses 的 `tools` 数组（type=function, name, parameters, strict=false）。
  - **SSE 翻译**（部分函数位于本文件）：
    - 负责从上游 SSE 流中解析事件，翻译为 OpenAI 兼容的 SSE 或一次性 JSON 响应结构。

- `chatmock/oauth.py`、`chatmock/models.py`
  - **职责**：
    - 定义 OAuth 相关 Pydantic/数据模型（如 `PkceCodes`）。
    - 提供登录、回调处理、token 解析与存储等工具。

### 3.6 Reasoning 模块

- `chatmock/reasoning.py`
  - **extract_reasoning_from_model_name(model_name)**：
    - 从模型名后缀中推断 reasoning effort（minimal/low/medium/high 等）。
  - **build_reasoning_param(effort, summary, overrides)**：
    - 将全局配置与请求级配置合并成 Responses `reasoning` 字段。
  - **apply_reasoning_to_message(message, summary_text, full_text, compat)**：
    - 根据 `compat` 策略将 reasoning 文本注入到最终返回给客户端的 message。
    - 例如：包裹在 `<think>` 标签中，或写入自定义元字段。

### 3.7 限流与 HTTP 辅助

- `chatmock/limits.py`
  - **record_rate_limits_from_response(upstream)**：
    - 从上游响应头中读取速率限制信息（如剩余配额、重置时间），并在本地进行记录或暴露，以便后续可观测性或限流逻辑使用。

- `chatmock/http.py`
  - **build_cors_headers()**：
    - 构造统一的 CORS 头（如 `Access-Control-Allow-Origin`, `Access-Control-Allow-Headers`, `Access-Control-Allow-Methods`）。
    - 在 `app.after_request` 中应用到所有响应。

## 4. 部署与运行架构

### 4.1 进程与部署拓扑

```mermaid
flowchart LR
    subgraph UserHost[用户主机]
        CLIProc["chatmock.py / gui.py\n进程"]
        WSProc["ChatMock Flask 进程"]
    end

    Client["前端应用 / 后端服务\n(通过 HTTP 调用 ChatMock)"]
    OpenAI["OpenAI ChatGPT Responses API"]

    Client -->|HTTP localhost:PORT| WSProc
    CLIProc --> WSProc
    WSProc -->|HTTPS| OpenAI
```

- 通常在本地通过 `python chatmock.py serve` 或 Docker 启动 Flask 服务。
- 默认在同一主机上，Flask 进程通过 OAuth 凭据与 OpenAI 云交互。

### 4.2 配置与安全

- OAuth 凭据保存在用户 home 目录下的 `auth.json`，文件权限设为 `600`。
- 通过环境变量（如 `CHATGPT_LOCAL_HOME`、`CODEX_HOME`）控制凭据目录位置。
- 上游访问使用 `https` 与 Bearer Token，session_id 不包含敏感内容，仅为 UUID 或缓存 key。

## 5. 扩展与演进方向

- **扩展模型/路由**：
  - 在 `routes_openai.py` 中增加更多 OpenAI 兼容端点（如 `/v1/embeddings`），在 `upstream.py` 中统一接入 Responses 或其他上游。
- **更丰富的工具与 web_search**：
  - 扩展 `responses_tools` 解析逻辑，支持自定义的工具类型及更复杂的参数结构。
- **限流与多租户**：
  - 在 `limits.py` 基础上实现本地限流、配额统计，以及对不同 account_id / client_session_id 的隔离。
- **观测性与调试**：
  - 标准化 `_chatmock_request_ctx`，将上游请求上下文通过日志或调试接口暴露出来，便于追踪问题。

## 6. Claude Code 下游 API 设计

本节在保持上游仅对接 ChatGPT Responses API 不变的前提下，细化 **在下游同时支持 OpenAI 兼容 API 与 Claude Code 风格 API** 的设计方案。Claude 相关的 API 差异与建议基于你提供的示例总结而来。

### 6.1 设计目标与约束

- **上游不变**：继续只调用 ChatGPT Responses API（`upstream.py` 无需引入 Claude/Anthropic 上游）。
- **下游多协议**：在现有 OpenAI 兼容接口基础上，增加一套 Claude Code 风格 HTTP API（结构对齐 Anthropic messages API）。
- **内部统一抽象**：
  - OpenAI & Claude Code 两种协议均转换为统一的 `InternalChatRequest` / `InternalChatResponse` 结构。
  - 再由 `upstream.start_upstream_request` 将该内部结构映射到 ChatGPT Responses API。
- **最小侵入改造**：
  - 现有 `routes_openai.py`、`upstream.py` 行为尽量保持不变，新增模块以适配 Claude Code。

### 6.2 Claude / ChatGPT API 差异归纳

结合示例代码与官方文档，两类 API 的差异大致可以归纳为：

- **max_tokens**：
  - Claude：通常为必需参数，用于限制输出 token 数。
  - ChatGPT：为可选参数，默认由后端自动控制。
- **system 提示词**：
  - Claude：通过独立的 `system` 字段传入系统提示。
  - ChatGPT：通常作为 `messages` 数组中的 `{"role": "system"}` 元素。
- **消息结构**：
  - Claude：`messages=[{"role": "user", "content": [{"type": "text", ...}, ...]}]`，`content` 是多模态数组（text/image/document）。
  - ChatGPT：`messages=[{"role": "user", "content": "..."}]` 或 `content` 为简单文本/结构化内容。
- **工具调用 (tools)**：
  - 两者都有 `tools` 概念，但字段名与 JSON 结构略有不同；需要在适配层进行转换和裁剪。
- **流式响应 (stream)**：
  - Claude & ChatGPT 均使用 `stream=True`，但事件类型和字段名称不同；在 ChatMock 中统一转换为内部事件，再映射到对应下游协议格式。

在 ChatMock 中，这些差异将被封装在路由层和转换层，避免污染上游调用逻辑。

### 6.3 新增 Claude Code 路由蓝图

新增 `chatmock/routes_claude_code.py`，提供面向下游的 Claude Code 风格 HTTP 接口：

- **典型路由设计**：
  - `POST /claude/v1/code/completions`
  - `POST /claude/v1/chat/completions`

- **总体处理流程**：
  1. 解析请求体（JSON），读取：
     - `model`、`max_tokens`（若缺失则给出默认值或返回 400）。
     - `system` 字段（若存在），以及 `messages` 数组。
     - `tools`、`stream`、项目上下文、文件路径等扩展字段（如 `files`、`context`）。
  2. 调用转换层 `transform.from_claude_code_request(payload)`：
     - 将 Claude 风格的 `system`/`messages`/`tools` 转换为内部 `InternalChatRequest`：
       - `system` → 内部 `instructions`。
       - `messages` → 内部 `messages`（统一成 ChatMock 现有的 `input_items` 构造所需格式）。
       - `max_tokens` → 映射为上游 Responses 的限制参数（可以附加在 `reasoning` 或使用上游对应字段）。
     - 处理多模态内容：将 Claude `content` 中的 `type=text/image` 转换为 ChatMock 当前使用的 `input_text` / `input_image` 结构。
  3. 根据请求中的 `reasoning` 或模型名，构造 `reasoning_param`（重用 `reasoning.py` 逻辑）。
  4. 调用 `upstream.start_upstream_request`：
     - 上游依然是 ChatGPT Responses API，不直接调用 Claude/Anthropic。
  5. 解析上游 SSE：将 `response.output_text.delta`、`response.reasoning_*` 等事件聚合为 `InternalChatResponse` 或流式内部事件。
  6. 调用 `transform.to_claude_code_response(...)`：
     - 将内部结构转换为 Claude Code 习惯使用的 JSON 结构：
       - 顶层字段（如 `id`、`type`、`model`、`usage`）。
       - `content` 数组中的 `text` 类型片段。
       - 工具调用/函数调用的结构（若需要，与 Claude 习惯格式对齐）。
  7. 根据 `stream` 参数决定返回方式：
     - `stream=True`：以 SSE 事件流返回，事件 payload 为 Claude 风格结构。
     - `stream=False`：返回一次性 JSON 响应。

- **与 app.py 集成**：
  - 在 `create_app` 中注册蓝图：
    - `app.register_blueprint(claude_code_bp, url_prefix="/claude")`

### 6.4 转换层（transform.py）细化

在前面的高层设计中已经引入 `transform.py` 的概念，此处基于 Claude / ChatGPT 差异进一步细化：

- **内部数据模型（示意）**：
  - `InternalChatRequest`：
    - 字段：`model`, `instructions`, `messages`, `tools`, `reasoning`, `stream`, `max_output_tokens`, `metadata` 等。
  - `InternalChatMessage`：
    - 字段：`role` (user/assistant/tool/system)、`content`（标准化后的文本/图片对象数组）。
  - `InternalChatResponse` / `InternalChatChunk`：
    - 字段：`id`, `model`, `output_text`, `reasoning_summary`, `reasoning_full`, `tool_calls`, `usage` 等。

- **转换函数**：
  - OpenAI 路由使用：
    - `from_openai_chat_request(payload) -> InternalChatRequest`
    - `to_openai_chat_response(internal) -> dict`
  - Claude Code 路由使用：
    - `from_claude_code_request(payload) -> InternalChatRequest`
    - `to_claude_code_response(internal) -> dict`

- **Claude 相关细节处理**：
  - **system 提示词**：
    - 从 Claude 请求的 `system` 字段中取出基础系统提示，如果下游仍附加了 `role=system` 的 message，则进行合并/去重。
  - **max_tokens 必填**：
    - 校验 Claude 请求是否提供 `max_tokens`，若缺失：
      - 可采用配置中的默认 `CLAUDE_CODE_MAX_TOKENS_DEFAULT`；
      - 或返回 400 提示调用方补充，视产品策略而定。
  - **文件内容注入**：
    - 对于 `files` 字段，可在转换层读取本地文件，并将内容以追加 `content` text 段的方式加入到内部消息中：
      - 例如：“File: path\n```\n内容\n```”。
    - 该行为对应你示例中的 `_prepare_messages` 逻辑，只是放在服务端转换层执行。

### 6.5 流式响应、对话历史与上下文

- **流式响应**：
  - 继续依赖 Responses API 的 SSE 输出，在 `utils` 中统一解析事件。
  - 对 Claude Code 路由：
    - 将内部事件按 Claude 规范序列化为 SSE `data: {...}`；
    - 保证事件顺序和结束标志（如 `[DONE]`）与 Claude 客户端预期一致。

- **对话历史**：
  - ChatMock 本身是无状态 HTTP 服务，但可以依赖：
    - 客户端将历史消息重新发回；或
    - 通过 `session_id` / `prompt_cache_key` 利用上游缓存能力。
  - 在 Claude Code 路由中，保持与 OpenAI 路由一致的策略：
    - 不在服务端持久化完整对话，只依赖请求内消息或上游 cache。

- **项目上下文 (context)**：
  - 对于代码任务，可在请求中提供 `context` 字段（如语言、框架、依赖等），
    - 转换层将其拼接进 `instructions` 或首条 user message，类似你示例中的 `_build_system_prompt` 行为。

### 6.6 与现有 OpenAI API 的统一抽象

结合你提供的 `UnifiedCodeAPI` 思路，可以把 ChatMock 的 HTTP 设计理解为“服务端版 UnifiedCodeAPI”：

- **客户端视角**：
  - OpenAI 客户端：继续调用 `/v1/chat/completions`、`/v1/completions` 等现有接口，不感知 Claude Code 的存在。
  - Claude Code 客户端：调用 `/claude/v1/...` 路径，使用 Claude 习惯的请求结构（`system` + 多模态 `content` + 必填 `max_tokens`）。

- **服务端视角**：
  - `routes_openai.py` 相当于 `_openai_chat` 适配层；
  - `routes_claude_code.py` 相当于 `_claude_chat` 适配层；
  - 二者都依赖 `transform.py`（统一内部结构）和 `upstream.py`（统一上游 ChatGPT 调用）。

通过这种分层设计，可以在 **不改动上游 ChatGPT 依赖** 的前提下，为下游新增完整的 Claude Code API 能力，同时保持架构清晰、可扩展。

以上是包含 Claude Code 下游扩展后的 ChatMock 架构设计，可在实际实现过程中进一步细化到具体字段名与错误码策略，并在需要时拆分为独立的 Claude Code 专用文档。