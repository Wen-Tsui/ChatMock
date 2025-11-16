from __future__ import annotations

import json
import time
import uuid
from typing import Any, Dict, List

from flask import Blueprint, Response, current_app, jsonify, make_response, request

from .config import BASE_INSTRUCTIONS
from .limits import record_rate_limits_from_response
from .http import build_cors_headers
from .reasoning import build_reasoning_param, extract_reasoning_from_model_name
from .transform import (
    CLAUDE_CODE_DEFAULT_MAX_TOKENS,
    convert_claude_code_tools,
    format_claude_stream_chunk,
    finalize_claude_response,
    prepare_claude_code_conversation,
)
from .upstream import normalize_model_name, start_upstream_request
from .utils import convert_chat_messages_to_responses_input

claude_code_bp = Blueprint("claude_code", __name__, url_prefix="/claude")


def _extract_usage(evt: Dict[str, Any]) -> Dict[str, int] | None:
    try:
        usage = (evt.get("response") or {}).get("usage")
    except Exception:
        usage = None
    if not isinstance(usage, dict):
        return None
    try:
        prompt_tokens = int(usage.get("input_tokens") or 0)
        completion_tokens = int(usage.get("output_tokens") or 0)
    except Exception:
        prompt_tokens = usage.get("input_tokens") or 0
        completion_tokens = usage.get("output_tokens") or 0
    total_tokens = usage.get("total_tokens")
    if not isinstance(total_tokens, int):
        try:
            total_tokens = int(total_tokens)
        except Exception:
            total_tokens = prompt_tokens + completion_tokens
    return {
        "prompt_tokens": prompt_tokens,
        "completion_tokens": completion_tokens,
        "total_tokens": total_tokens,
    }


def _convert_tool_item(item: Any) -> tuple[Dict[str, Any] | None, Dict[str, Any] | None]:
    if not (isinstance(item, dict) and item.get("type") == "function_call"):
        return None, None
    call_id = item.get("call_id") or item.get("id") or f"claude_tool_{uuid.uuid4().hex}"
    name = item.get("name") or ""
    if not isinstance(name, str) or not name:
        return None, None
    raw_args = item.get("arguments")
    parsed_input: Any
    args_str: str
    if isinstance(raw_args, str):
        try:
            parsed_input = json.loads(raw_args)
            args_str = raw_args
        except Exception:
            parsed_input = {"raw": raw_args}
            args_str = json.dumps(parsed_input)
    elif isinstance(raw_args, (dict, list)):
        parsed_input = raw_args
        args_str = json.dumps(raw_args)
    else:
        parsed_input = {"raw": raw_args}
        args_str = json.dumps(parsed_input)
    call_payload = {
        "id": call_id,
        "type": "function",
        "function": {"name": name, "arguments": args_str},
    }
    stream_delta = {"type": "tool_use", "id": call_id, "name": name, "input": parsed_input}
    return call_payload, stream_delta


def _claude_instructions(model: str) -> str:
    base = current_app.config.get("BASE_INSTRUCTIONS", BASE_INSTRUCTIONS)
    return base


def _estimate_claude_token_count(instructions: str | None, input_items: List[Dict[str, Any]]) -> int:
    total_chars = len(instructions or "")
    for item in input_items or []:
        try:
            total_chars += len(json.dumps(item, ensure_ascii=False))
        except Exception:
            continue
    approx = total_chars // 4
    return max(0, approx)


@claude_code_bp.route("/v1/chat/completions", methods=["POST"])
@claude_code_bp.route("/v1/messages", methods=["POST"])
def claude_chat() -> Response:
    verbose = bool(current_app.config.get("VERBOSE"))
    reasoning_effort = current_app.config.get("REASONING_EFFORT", "medium")
    reasoning_summary = current_app.config.get("REASONING_SUMMARY", "auto")
    reasoning_compat = current_app.config.get("REASONING_COMPAT", "think-tags")

    raw = request.get_data(cache=True, as_text=True) or ""
    try:
        payload = json.loads(raw) if raw else {}
        if verbose:
            print("IN POST /claude/v1/chat/completions\n" + raw[:2000])
    except Exception:
        return jsonify({"error": {"message": "Invalid JSON body"}}), 400

    requested_model = payload.get("model")
    normalized_model = normalize_model_name(requested_model, current_app.config.get("DEBUG_MODEL"))
    if not normalized_model:
        return jsonify({"error": {"message": "Missing model"}}), 400

    max_tokens = payload.get("max_tokens")
    if not isinstance(max_tokens, int) or max_tokens <= 0:
        max_tokens = CLAUDE_CODE_DEFAULT_MAX_TOKENS

    instructions, messages = prepare_claude_code_conversation(
        payload,
        _claude_instructions(requested_model),
    )

    input_items = convert_chat_messages_to_responses_input(messages)

    model_reasoning = extract_reasoning_from_model_name(requested_model)
    reasoning_override = payload.get("reasoning") if isinstance(payload.get("reasoning"), dict) else model_reasoning
    reasoning_param = build_reasoning_param(reasoning_effort, reasoning_summary, reasoning_override)

    tools = convert_claude_code_tools(payload.get("tools"))
    tool_choice = payload.get("tool_choice", "auto")
    if isinstance(tool_choice, dict):
        choice_type = tool_choice.get("type")
        if choice_type == "function":
            name = tool_choice.get("name")
            if not isinstance(name, str) or not name.strip():
                fn = tool_choice.get("function")
                if isinstance(fn, dict):
                    name = fn.get("name")
            if isinstance(name, str) and name.strip():
                tool_choice = {"type": "function", "name": name.strip()}
            else:
                tool_choice = "auto"
        elif isinstance(choice_type, str) and choice_type in ("auto", "none"):
            tool_choice = choice_type

    upstream, error_resp = start_upstream_request(
        normalized_model,
        input_items,
        instructions=instructions,
        tools=tools,
        tool_choice=tool_choice,
        reasoning_param=reasoning_param,
    )
    if error_resp is not None:
        return error_resp

    record_rate_limits_from_response(upstream)

    created = int(time.time())
    if upstream.status_code >= 400:
        try:
            err_body = json.loads(upstream.content.decode("utf-8", errors="ignore")) if upstream.content else {"raw": upstream.text}
        except Exception:
            err_body = {"raw": upstream.text}
        log_body = err_body if isinstance(err_body, dict) else {"raw": upstream.text}
        log_payload = {
            "status_code": upstream.status_code,
            "upstream_body": log_body,
            "requested_model": requested_model,
        }
        try:
            current_app.logger.error("Claude upstream request failed", extra=log_payload)
        except Exception:
            pass
        print(
            "[claude] upstream error status={status} model={model} body={body}".format(
                status=upstream.status_code,
                model=requested_model,
                body=json.dumps(log_body)[:800] if isinstance(log_body, dict) else (upstream.text or "")[:800],
            )
        )
        return (
            jsonify(
                {
                    "error": {
                        "message": (log_body.get("error", {}) or {}).get("message", "Upstream error"),
                        "details": log_body,
                    }
                }
            ),
            upstream.status_code,
        )

    if payload.get("stream"):
        def _event_stream():
            response_id = "claude-msg"
            client_disconnected = False
            try:
                for raw_line in upstream.iter_lines(decode_unicode=False):
                    if not raw_line:
                        continue
                    line = raw_line.decode("utf-8", errors="ignore") if isinstance(raw_line, (bytes, bytearray)) else raw_line
                    if not line.startswith("data: "):
                        continue
                    data = line[len("data: "):].strip()
                    if not data:
                        continue
                    if data == "[DONE]":
                        break
                    try:
                        evt = json.loads(data)
                    except Exception:
                        continue
                    kind = evt.get("type")
                    if isinstance(evt.get("response"), dict) and isinstance(evt["response"].get("id"), str):
                        response_id = evt["response"].get("id") or response_id
                    if kind == "response.output_text.delta":
                        chunk = format_claude_stream_chunk(
                            response_id=response_id,
                            model=requested_model,
                            content_delta=evt.get("delta") or "",
                        )
                        yield f"data: {json.dumps(chunk)}\n\n"
                    elif kind in ("response.reasoning_summary_text.delta", "response.reasoning_text.delta"):
                        delta = evt.get("delta") or ""
                        chunk = format_claude_stream_chunk(
                            response_id=response_id,
                            model=requested_model,
                            reasoning_delta=delta,
                        )
                        yield f"data: {json.dumps(chunk)}\n\n"
                    elif kind == "response.output_item.done":
                        tool_payload, tool_delta = _convert_tool_item(evt.get("item"))
                        if tool_delta:
                            chunk = format_claude_stream_chunk(
                                response_id=response_id,
                                model=requested_model,
                                content_delta=None,
                                tool_call_delta=tool_delta,
                            )
                            yield f"data: {json.dumps(chunk)}\n\n"
            except GeneratorExit:
                client_disconnected = True
            finally:
                upstream.close()
            if client_disconnected:
                return
            stop_chunk = format_claude_stream_chunk(
                response_id=response_id,
                model=requested_model,
                stop_reason="end_turn",
                done=True,
            )
            yield f"data: {json.dumps(stop_chunk)}\n\n"
            yield "data: [DONE]\n\n"
        resp = Response(
            _event_stream(),
            status=200,
            mimetype="text/event-stream",
            headers={"Cache-Control": "no-cache", "Connection": "keep-alive"},
        )
        for k, v in build_cors_headers().items():
            resp.headers.setdefault(k, v)
        return resp

    full_text = ""
    reasoning_text = ""
    usage_obj: Dict[str, int] | None = None
    tool_calls: List[Dict[str, Any]] = []
    response_id = "claude-msg"
    error_message: str | None = None
    try:
        for raw_line in upstream.iter_lines(decode_unicode=False):
            if not raw_line:
                continue
            line = raw_line.decode("utf-8", errors="ignore") if isinstance(raw_line, (bytes, bytearray)) else raw_line
            if not line.startswith("data: "):
                continue
            data = line[len("data: "):].strip()
            if not data:
                continue
            if data == "[DONE]":
                break
            try:
                evt = json.loads(data)
            except Exception:
                continue
            kind = evt.get("type")
            usage_delta = _extract_usage(evt)
            if usage_delta:
                usage_obj = usage_delta
            if isinstance(evt.get("response"), dict) and isinstance(evt["response"].get("id"), str):
                response_id = evt["response"].get("id") or response_id
            if kind == "response.output_text.delta":
                full_text += evt.get("delta") or ""
            elif kind in ("response.reasoning_summary_text.delta", "response.reasoning_text.delta"):
                reasoning_text += evt.get("delta") or ""
            elif kind == "response.output_item.done":
                call_payload, _ = _convert_tool_item(evt.get("item"))
                if call_payload:
                    tool_calls.append(call_payload)
            elif kind == "response.failed":
                error_message = evt.get("response", {}).get("error", {}).get("message", "response.failed")
                break
            elif kind == "response.completed":
                break
    finally:
        upstream.close()

    if error_message:
        resp = make_response(jsonify({"error": {"message": error_message}}), 502)
        for k, v in build_cors_headers().items():
            resp.headers.setdefault(k, v)
        return resp

    completion = finalize_claude_response(
        response_id=response_id,
        model=requested_model,
        content=full_text,
        reasoning=reasoning_text,
        tool_calls=tool_calls,
        usage=usage_obj,
    )
    resp = make_response(jsonify(completion), 200)
    for k, v in build_cors_headers().items():
        resp.headers.setdefault(k, v)
    return resp


@claude_code_bp.route("/v1/messages/count_tokens", methods=["POST"])
def claude_count_tokens() -> Response:
    verbose = bool(current_app.config.get("VERBOSE"))
    raw = request.get_data(cache=True, as_text=True) or ""
    try:
        payload = json.loads(raw) if raw else {}
        if verbose:
            print("IN POST /claude/v1/messages/count_tokens\n" + raw[:2000])
    except Exception:
        return jsonify({"error": {"message": "Invalid JSON body"}}), 400

    requested_model = payload.get("model")
    instructions, messages = prepare_claude_code_conversation(
        payload,
        _claude_instructions(requested_model),
    )
    input_items = convert_chat_messages_to_responses_input(messages)
    approx_tokens = _estimate_claude_token_count(instructions, input_items)
    body = {
        "input_tokens": approx_tokens,
        "cache_create_input_tokens": 0,
        "cache_read_input_tokens": 0,
    }
    resp = jsonify(body)
    for k, v in build_cors_headers().items():
        resp.headers.setdefault(k, v)
    return resp
