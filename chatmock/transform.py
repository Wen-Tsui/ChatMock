from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any, Dict, List, Tuple
import uuid


def to_data_url(image_str: str) -> str:
    if not isinstance(image_str, str) or not image_str:
        return image_str
    s = image_str.strip()
    if s.startswith("data:image/"):
        return s
    if s.startswith("http://") or s.startswith("https://"):
        return s
    b64 = s.replace("\n", "").replace("\r", "")
    kind = "image/png"
    if b64.startswith("/9j/"):
        kind = "image/jpeg"
    elif b64.startswith("iVBORw0KGgo"):
        kind = "image/png"
    elif b64.startswith("R0lGOD"):
        kind = "image/gif"
    return f"data:{kind};base64,{b64}"


def convert_ollama_messages(
    messages: List[Dict[str, Any]] | None, top_images: List[str] | None
) -> List[Dict[str, Any]]:
    out: List[Dict[str, Any]] = []
    msgs = messages if isinstance(messages, list) else []
    pending_call_ids: List[str] = []
    call_counter = 0
    for m in msgs:
        if not isinstance(m, dict):
            continue
        role = m.get("role") or "user"
        nm: Dict[str, Any] = {"role": role}

        content = m.get("content")
        images = m.get("images") if isinstance(m.get("images"), list) else []
        parts: List[Dict[str, Any]] = []
        if isinstance(content, list):
            for p in content:
                if isinstance(p, dict) and p.get("type") == "text" and isinstance(p.get("text"), str):
                    parts.append({"type": "text", "text": p.get("text")})
        elif isinstance(content, str):
            parts.append({"type": "text", "text": content})
        for img in images:
            url = to_data_url(img)
            if isinstance(url, str) and url:
                parts.append({"type": "image_url", "image_url": {"url": url}})
        if parts:
            nm["content"] = parts

        if role == "assistant" and isinstance(m.get("tool_calls"), list):
            tcs = []
            for tc in m.get("tool_calls"):
                if not isinstance(tc, dict):
                    continue
                fn = tc.get("function") if isinstance(tc.get("function"), dict) else {}
                name = fn.get("name") if isinstance(fn.get("name"), str) else None
                args = fn.get("arguments")
                if name is None:
                    continue
                call_id = tc.get("id") or tc.get("call_id")
                if not isinstance(call_id, str) or not call_id:
                    call_counter += 1
                    call_id = f"ollama_call_{call_counter}"
                pending_call_ids.append(call_id)
                tcs.append(
                    {
                        "id": call_id,
                        "type": "function",
                        "function": {
                            "name": name,
                            "arguments": args if isinstance(args, str) else (json.dumps(args) if isinstance(args, dict) else "{}"),
                        },
                    }
                )
            if tcs:
                nm["tool_calls"] = tcs

        if role == "tool":
            tci = m.get("tool_call_id") or m.get("id")
            if not isinstance(tci, str) or not tci:
                if pending_call_ids:
                    tci = pending_call_ids.pop(0)
            if isinstance(tci, str) and tci:
                nm["tool_call_id"] = tci

            if not parts and isinstance(content, str):
                nm["content"] = content

        out.append(nm)

    if isinstance(top_images, list) and top_images:
        attach_to = None
        for i in range(len(out) - 1, -1, -1):
            if out[i].get("role") == "user":
                attach_to = out[i]
                break
        if attach_to is None:
            attach_to = {"role": "user", "content": []}
            out.append(attach_to)
        attach_to.setdefault("content", [])
        for img in top_images:
            url = to_data_url(img)
            if isinstance(url, str) and url:
                attach_to["content"].append({"type": "image_url", "image_url": {"url": url}})
    return out


def normalize_ollama_tools(tools: List[Dict[str, Any]] | None) -> List[Dict[str, Any]]:
    out: List[Dict[str, Any]] = []
    if not isinstance(tools, list):
        return out
    for t in tools:
        if not isinstance(t, dict):
            continue
        if isinstance(t.get("function"), dict):
            fn = t.get("function")
            name = fn.get("name") if isinstance(fn.get("name"), str) else None
            if not name:
                continue
            out.append(
                {
                    "type": "function",
                    "function": {
                        "name": name,
                        "description": fn.get("description") or "",
                        "parameters": fn.get("parameters") if isinstance(fn.get("parameters"), dict) else {"type": "object", "properties": {}},
                    },
                }
            )
            continue
        name = t.get("name") if isinstance(t.get("name"), str) else None
        if name:
            out.append(
                {
                    "type": "function",
                    "function": {
                        "name": name,
                        "description": t.get("description") or "",
                        "parameters": {"type": "object", "properties": {}},
                    },
                }
            )
    return out


def _truncate_utf8(text: str, limit: int) -> str:
    if limit is None or limit <= 0:
        return text
    encoded = text.encode("utf-8")
    if len(encoded) <= limit:
        return text
    truncated = encoded[:limit]
    return truncated.decode("utf-8", errors="ignore") + "\n... (truncated)"


_CLAUDE_DEFAULT_FILES_ROOT = Path(os.getenv("CLAUDE_CODE_FILES_ROOT") or Path.cwd())
CLAUDE_CODE_FILES_MAX_BYTES = int(os.getenv("CLAUDE_CODE_FILES_MAX_BYTES", "200000"))
CLAUDE_CODE_DEFAULT_MAX_TOKENS = int(os.getenv("CLAUDE_CODE_DEFAULT_MAX_TOKENS", "2048"))


def _resolve_files_root(override: str | Path | None = None) -> Path:
    candidate = override or os.getenv("CLAUDE_CODE_FILES_ROOT")
    try:
        return Path(candidate).expanduser().resolve() if candidate else _CLAUDE_DEFAULT_FILES_ROOT
    except Exception:
        return _CLAUDE_DEFAULT_FILES_ROOT


def _safe_join(base: Path, target: str) -> Path | None:
    try:
        raw = Path(target)
        resolved = raw.expanduser().resolve() if raw.is_absolute() else (base / raw).expanduser().resolve()
        resolved.relative_to(base)
        return resolved
    except Exception:
        return None


def render_claude_code_file_snippets(
    files: Any,
    *,
    base_dir: str | Path | None = None,
    max_bytes: int | None = None,
) -> List[str]:
    snippets: List[str] = []
    if not isinstance(files, list):
        return snippets
    root = _resolve_files_root(base_dir)
    limit = max_bytes or CLAUDE_CODE_FILES_MAX_BYTES
    for entry in files:
        path_value = None
        label = None
        if isinstance(entry, str):
            path_value = entry
            label = entry
        elif isinstance(entry, dict):
            path_value = entry.get("path") or entry.get("file")
            label = entry.get("label") or entry.get("name") or path_value
        if not isinstance(path_value, str):
            continue
        resolved = _safe_join(root, path_value)
        if resolved is None or not resolved.is_file():
            continue
        try:
            data = resolved.read_text(encoding="utf-8")
        except Exception:
            continue
        text = _truncate_utf8(data, limit)
        snippets.append(f"File: {label or resolved.name}\n```\n{text}\n```")
    return snippets


def build_claude_code_instructions(
    base_instructions: str,
    system_prompt: Any = None,
    *contexts: Any,
) -> str:
    extras: List[str] = []
    if isinstance(system_prompt, str) and system_prompt.strip():
        extras.append(system_prompt.strip())
    for ctx in contexts:
        if isinstance(ctx, str) and ctx.strip():
            extras.append(f"Context:\n{ctx.strip()}")
    if not extras:
        return base_instructions
    joined = "\n\n".join(extras)
    base = base_instructions or ""
    if base.endswith("\n"):
        base = base.rstrip("\n")
    if base:
        return f"{base}\n\n{joined}"
    return joined


def _normalize_block_list(content: Any) -> List[Dict[str, Any]]:
    if isinstance(content, list):
        return [block for block in content if isinstance(block, dict)]
    if isinstance(content, dict):
        return [content]
    if isinstance(content, str):
        return [{"type": "text", "text": content}]
    return []


def _image_block_to_part(block: Dict[str, Any]) -> Dict[str, Any] | None:
    if block.get("type") == "image_url":
        url = block.get("url") or block.get("href")
        if isinstance(url, str) and url:
            return {"type": "image_url", "image_url": {"url": url}}
    source = block.get("source") if isinstance(block.get("source"), dict) else {}
    if source.get("type") == "base64":
        media = source.get("media_type") or "image/png"
        data = source.get("data")
        if isinstance(data, str) and data:
            return {"type": "image_url", "image_url": {"url": f"data:{media};base64,{data}"}}
    if source.get("type") == "url":
        url = source.get("url")
        if isinstance(url, str) and url:
            return {"type": "image_url", "image_url": {"url": url}}
    return None


def _build_tool_call(block: Dict[str, Any]) -> Tuple[Dict[str, Any] | None, str | None]:
    name = block.get("name") or block.get("tool_name")
    if not isinstance(name, str) or not name:
        return None, None
    call_id = block.get("id")
    if not isinstance(call_id, str) or not call_id:
        call_id = f"claude_tool_{uuid.uuid4().hex}"
    raw_input = block.get("input")
    if isinstance(raw_input, (dict, list)):
        args = json.dumps(raw_input)
    elif isinstance(raw_input, str):
        args = raw_input
    else:
        args = json.dumps(raw_input)
    call = {
        "id": call_id,
        "type": "function",
        "function": {"name": name, "arguments": args},
    }
    return call, block.get("id") if isinstance(block.get("id"), str) else call_id


def _build_tool_result_message(block: Dict[str, Any], call_id_map: Dict[str, str]) -> Dict[str, Any] | None:
    tool_use_id = block.get("tool_use_id") or block.get("id")
    if not isinstance(tool_use_id, str) or not tool_use_id:
        tool_use_id = f"claude_tool_{uuid.uuid4().hex}"
    call_id = call_id_map.get(tool_use_id, tool_use_id)
    content = block.get("content")
    text_out: str
    if isinstance(content, list):
        texts = []
        for part in content:
            if isinstance(part, dict) and part.get("type") == "text" and isinstance(part.get("text"), str):
                texts.append(part.get("text"))
        text_out = "\n".join(texts)
    elif isinstance(content, str):
        text_out = content
    else:
        text_out = json.dumps(content)
    return {"role": "tool", "tool_call_id": call_id, "content": text_out}


def _append_blocks_to_first_user(messages: List[Dict[str, Any]], snippets: List[str]) -> List[Dict[str, Any]]:
    if not snippets:
        return messages
    out = list(messages)
    target = None
    for msg in out:
        if msg.get("role") == "user":
            target = msg
            break
    if target is None:
        target = {"role": "user", "content": []}
        out.insert(0, target)
    content = target.get("content")
    if isinstance(content, str):
        content_list = [{"type": "text", "text": content}]
    elif isinstance(content, list):
        content_list = list(content)
    else:
        content_list = []
    for snippet in snippets:
        content_list.append({"type": "text", "text": snippet})
    target["content"] = content_list
    return out


def normalize_claude_code_messages(raw_messages: Any) -> List[Dict[str, Any]]:
    normalized: List[Dict[str, Any]] = []
    messages = raw_messages if isinstance(raw_messages, list) else []
    call_id_map: Dict[str, str] = {}
    for msg in messages:
        if not isinstance(msg, dict):
            continue
        role = msg.get("role") or "user"
        if role not in ("user", "assistant", "tool"):
            role = "user"
        parts: List[Dict[str, Any]] = []
        tool_calls: List[Dict[str, Any]] = []

        def flush_current() -> None:
            if not parts and not (role == "assistant" and tool_calls):
                return
            entry = {"role": role}
            if parts:
                entry["content"] = list(parts)
            else:
                entry["content"] = ""
            if role == "assistant" and tool_calls:
                entry["tool_calls"] = list(tool_calls)
            normalized.append(entry)
            parts.clear()
            tool_calls.clear()

        for block in _normalize_block_list(msg.get("content")):
            btype = block.get("type")
            if btype in ("text", "code", "output_text"):
                text = block.get("text") or block.get("content") or ""
                if isinstance(text, str) and text:
                    parts.append({"type": "text", "text": text})
            elif btype in ("image", "image_url"):
                img_part = _image_block_to_part(block)
                if img_part:
                    parts.append(img_part)
            elif btype == "tool_use":
                call, original_id = _build_tool_call(block)
                if call:
                    tool_calls.append(call)
                    if isinstance(original_id, str):
                        call_id_map[original_id] = call["id"]
            elif btype == "tool_result":
                flush_current()
                tool_msg = _build_tool_result_message(block, call_id_map)
                if tool_msg:
                    normalized.append(tool_msg)
            else:
                text = block.get("text") if isinstance(block.get("text"), str) else None
                if text:
                    parts.append({"type": "text", "text": text})
        flush_current()
    return normalized


def prepare_claude_code_conversation(
    payload: Dict[str, Any],
    base_instructions: str,
    *,
    files_base_dir: str | Path | None = None,
    max_file_bytes: int | None = None,
) -> Tuple[str, List[Dict[str, Any]]]:
    messages = normalize_claude_code_messages(payload.get("messages"))
    snippets = render_claude_code_file_snippets(
        payload.get("files"), base_dir=files_base_dir, max_bytes=max_file_bytes
    )
    if snippets:
        messages = _append_blocks_to_first_user(messages, snippets)
    instructions = build_claude_code_instructions(
        base_instructions,
        payload.get("system"),
        payload.get("context"),
        payload.get("project_context"),
    )
    return instructions, messages


def _normalize_tool_schema(
    *,
    name: str | None,
    description: str | None,
    schema: Dict[str, Any] | None,
) -> Dict[str, Any] | None:
    if not isinstance(name, str) or not name.strip():
        return None
    if not isinstance(schema, dict):
        schema = {"type": "object", "properties": {}}
    schema = dict(schema)
    schema.setdefault("type", "object")
    if not isinstance(schema.get("properties"), dict):
        schema["properties"] = {}
    return {
        "type": "function",
        "name": name.strip(),
        "description": description or "",
        "parameters": schema,
    }


def convert_claude_code_tools(tools: Any) -> List[Dict[str, Any]]:
    normalized: List[Dict[str, Any]] = []
    if not isinstance(tools, list):
        return normalized
    for tool in tools:
        if not isinstance(tool, dict):
            continue
        name: str | None = None
        description: str | None = None
        schema: Dict[str, Any] | None = None

        if tool.get("type") == "function" and isinstance(tool.get("function"), dict):
            fn_def = tool.get("function") or {}
            name = fn_def.get("name") or tool.get("name")
            description = fn_def.get("description") or tool.get("description") or tool.get("summary")
            schema = (
                fn_def.get("parameters")
                or fn_def.get("input_schema")
                or tool.get("parameters")
                or tool.get("input_schema")
            )
        else:
            name = tool.get("name") or tool.get("tool")
            description = tool.get("description") or tool.get("summary")
            schema = tool.get("input_schema") or tool.get("parameters")

        normalized_tool = _normalize_tool_schema(name=name, description=description, schema=schema)
        if normalized_tool:
            normalized.append(normalized_tool)
    return normalized


def format_claude_stream_chunk(
    *,
    response_id: str,
    model: str,
    content_delta: str | None = None,
    usage: Dict[str, int] | None = None,
    stop_reason: str | None = None,
    done: bool = False,
    tool_call_delta: Dict[str, Any] | None = None,
    reasoning_delta: str | None = None,
) -> Dict[str, Any]:
    chunk: Dict[str, Any] = {
        "type": "message_delta" if not done else "message_stop",
        "id": response_id,
        "model": model,
    }
    if not done:
        delta: Dict[str, Any] = {"messages": [{"role": "assistant", "content": []}]}
        if isinstance(content_delta, str) and content_delta:
            delta["messages"][0]["content"].append({"type": "text_delta", "text": content_delta})
        if isinstance(reasoning_delta, str) and reasoning_delta:
            delta["messages"][0]["content"].append({"type": "reasoning_delta", "text": reasoning_delta})
        if isinstance(tool_call_delta, dict):
            delta.setdefault("tool_calls", []).append(tool_call_delta)
        if stop_reason:
            delta["stop_reason"] = stop_reason
        chunk["delta"] = delta
    else:
        finished: Dict[str, Any] = {
            "status": "stopped",
            "stop_reason": stop_reason or "end_turn",
        }
        if usage:
            finished["usage"] = usage
        chunk["message"] = finished
    return chunk


def finalize_claude_response(
    *,
    response_id: str,
    model: str,
    content: str,
    reasoning: str | None,
    tool_calls: List[Dict[str, Any]],
    usage: Dict[str, int] | None = None,
    stop_reason: str = "end_turn",
) -> Dict[str, Any]:
    message_content: List[Dict[str, Any]] = []
    if isinstance(reasoning, str) and reasoning.strip():
        message_content.append({"type": "reasoning", "text": reasoning})
    if content:
        message_content.append({"type": "text", "text": content})
    for tool_call in tool_calls:
        message_content.append(
            {
                "type": "tool_use",
                "id": tool_call.get("id"),
                "name": tool_call.get("function", {}).get("name"),
                "input": json.loads(tool_call.get("function", {}).get("arguments", "{}"))
                if isinstance(tool_call.get("function", {}), dict)
                else {},
            }
        )
    response = {
        "id": response_id,
        "type": "message",
        "model": model,
        "role": "assistant",
        "content": message_content,
        "stop_reason": stop_reason,
    }
    if usage:
        response["usage"] = usage
    return response
