#!/usr/bin/env bash
# 从 Agent 输出中提取 JSON（处理 markdown 包裹和前置文本）
# Usage: echo "$output" | extract_json
# 优先找 ```json...``` 块，否则找第一个 {...} 块

extract_json() {
  local input
  input=$(cat)

  # 尝试1：提取 ```json ... ``` 块
  local json_block
  json_block=$(echo "$input" | sed -n '/^```json/,/^```$/p' | sed '1d;$d')
  if [ -n "$json_block" ] && echo "$json_block" | jq . >/dev/null 2>&1; then
    echo "$json_block"
    return 0
  fi

  # 尝试2：直接当 JSON 解析
  if echo "$input" | jq . >/dev/null 2>&1; then
    echo "$input"
    return 0
  fi

  # 尝试3：找最后一行像 JSON 的内容（Agent 经常先输出解释文本再输出 JSON）
  local last_json
  last_json=$(echo "$input" | grep -E '^\{' | tail -1)
  if [ -n "$last_json" ] && echo "$last_json" | jq . >/dev/null 2>&1; then
    echo "$last_json"
    return 0
  fi

  # 全部失败，原样输出
  echo "$input"
  return 1
}
