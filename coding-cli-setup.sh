#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# coding-cli-setup.sh — Interactive setup for multiple coding CLIs on Linux/macOS
# Supports:
#   1) Factory Droid CLI (~/.factory/config.json)
#   2) OpenAI Codex CLI (~/.codex/config.toml + ~/.codex/auth.json)
#   3) Anthropic Claude Code CLI (ANTHROPIC_* envs in ~/.bashrc / ~/.zshrc)
#
# 站点选项（每个应用内均提供）：
#   1) ZetaTechs API 主站:   https://api.zetatechs.com(/v1)
#   2) ZetaTechs API 企业站: https://ent.zetatechs.com(/v1)
#   3) ZetaTechs API Codex站: https://codex.zetatechs.com(/v1)
#   4) 自定义: 手动输入 base_url（会给出 1 号站点作为格式示例），随后输入 API Key
#
# 行为说明：
# - 再次运行时若直接回车不选择站点/不输入 Key，将保持原值不变。
# - 若选择“自定义”，会要求输入新的 base_url；之后照常提示输入 API Key。
# - 推荐安装 jq 以确保写入合法 JSON。
#
# Copyright (c) 2025

set -Eeuo pipefail
umask 077

# Ensure interactive terminal when piped
if ! [ -r /dev/tty ]; then
  echo "ERROR: /dev/tty is not readable. Please run in a terminal." >&2
  exit 1
fi

# -------- Utils --------
has_cmd() { command -v "$1" >/dev/null 2>&1; }
trim() { printf "%s" "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }
read_tty() { local __p="${1:-}"; local input; read -r -p "$__p" input < /dev/tty || true; printf "%s" "${input:-}"; }
read_secret_tty() { local __p="${1:-}"; local input; read -r -s -p "$__p" input < /dev/tty || true; echo; printf "%s" "${input:-}"; }
timestamp() { date +"%Y%m%d-%H%M%S"; }

json_escape() {
  # minimal JSON string escaper
  printf "%s" "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g' -e 's/\r/\\r/g' -e 's/\n/\\n/g'
}

sh_single_quote() { printf "'%s'" "$(printf "%s" "$1" | sed "s/'/'\\\\''/g")"; }

# Upsert export KEY='value' into an rc file (idempotent)
upsert_export() {
  local rcfile="${1:-}" key="${2:-}" val="${3:-}"
  [ -z "$rcfile" ] && return 1
  [ -z "$key" ] && return 1
  [ -z "$val" ] && return 0
  mkdir -p "$(dirname "$rcfile")"
  [ -f "$rcfile" ] || touch "$rcfile"

  local line="export $key=$(sh_single_quote "$val")"
  local pattern="^[[:space:]]*(export[[:space:]]+)?$key="

  if grep -Eq "$pattern" "$rcfile"; then
    # Replace existing line
    sed -i.bak -E "s|$pattern.*$|$line|g" "$rcfile"
    rm -f "$rcfile.bak" 2>/dev/null || true
  else
    printf "%s\n" "$line" >> "$rcfile"
  fi
}

# Read env value from runtime or rc files (best-effort)
read_env_from_rcs() {
  local key="${1:-}" val=""
  [ -z "$key" ] && { printf "%s" ""; return 0; }
  val="$(printenv "$key" || true)"
  if [ -n "$val" ]; then printf "%s" "$val"; return 0; fi
  for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    [ -f "$rc" ] || continue
    local line
    line="$(grep -E '^[[:space:]]*(export[[:space:]]+)?'"$key"'=' "$rc" | tail -n1 || true)"
    [ -z "$line" ] && continue
    line="${line#export }"
    line="${line#"$key"=}"
    line="$(trim "$line")"
    line="$(printf "%s" "$line" | sed -E "s/^'(.*)'\$/\1/; s/^\"(.*)\"\$/\1/")"
    val="$line"
    break
  done
  printf "%s" "$val"
}

extract_host() {
  # From https://host/xxx -> host
  printf "%s" "$1" | sed -n 's#^https\?://\([^/]*\).*#\1#p'
}

ensure_scheme() {
  # Ensure base_url includes scheme; default https
  case "$1" in
    http://*|https://*) printf "%s" "$1" ;;
    *) printf "https://%s" "$1" ;;
  esac
}

# Globals set by select_site/prompt_api_key
NEW_BASE_URL=""
TOKEN_URL=""
SITE_NAME=""
KEPT_BASE=false
NEW_API_KEY=""
KEPT_KEY=false

select_site() {
  # Args: app_label base_suffix existing_base_url
  local app_label="${1:-}" base_suffix="${2:-}" existing="${3:-}"
  local example_url="https://api.zetatechs.com${base_suffix}"

  echo
  echo "请选择 ${app_label} API 站点："
  echo "  1) ZetaTechs API 主站:   ${example_url}"
  echo "  2) ZetaTechs API 企业站: https://ent.zetatechs.com${base_suffix}"
  echo "  3) ZetaTechs API Codex站: https://codex.zetatechs.com${base_suffix}"
  echo "  4) 自定义: 手动输入 base_url（示例: ${example_url}）"

  local choice
  if [ -n "${existing:-}" ]; then
    echo "提示：按 Enter 保持不变（当前: ${existing}）"
    choice="$(read_tty "输入选项 [1/2/3/4]，或直接回车保持不变: ")"
  else
    choice="$(read_tty "输入选项 [1/2/3/4] (默认 1): ")"
  fi
  choice="${choice:-}"

  KEPT_BASE=false
  if [ -z "$choice" ]; then
    if [ -n "${existing:-}" ]; then
      KEPT_BASE=true
      NEW_BASE_URL="${existing}"
      local host; host="$(extract_host "${existing}")"
      if [ -n "$host" ]; then TOKEN_URL="https://${host}/console/token"; else TOKEN_URL=""; fi
      SITE_NAME="保持不变"
      return 0
    else
      choice="1"
    fi
  fi

  local host=""
  case "$choice" in
    1) host="api.zetatechs.com"; SITE_NAME="主站"; NEW_BASE_URL="https://${host}${base_suffix}" ;;
    2) host="ent.zetatechs.com"; SITE_NAME="企业站"; NEW_BASE_URL="https://${host}${base_suffix}" ;;
    3) host="codex.zetatechs.com"; SITE_NAME="Codex站"; NEW_BASE_URL="https://${host}${base_suffix}" ;;
    4)
      SITE_NAME="自定义"
      echo
      echo "请输入完整 base_url（以 http(s):// 开头）。"
      echo "示例（与 1 号站点一致的格式）: ${example_url}"
      local custom
      custom="$(read_tty "自定义 base_url: ")"
      custom="$(trim "$custom")"
      if [ -z "$custom" ]; then
        echo "ERROR: base_url 不能为空。" >&2
        exit 1
      fi
      custom="$(ensure_scheme "$custom")"
      NEW_BASE_URL="$custom"
      host="$(extract_host "$custom")"
      ;;
    *) echo "无效选项：$choice" >&2; exit 1 ;;
  esac

  if [ -z "$host" ]; then
    host="$(extract_host "$NEW_BASE_URL")"
  fi
  if [ -n "$host" ]; then TOKEN_URL="https://${host}/console/token"; else TOKEN_URL=""; fi
}

prompt_api_key() {
  # Args: key_label existing_key token_url
  local key_label="${1:-}" existing="${2:-}" token_url="${3:-}"
  echo
  if [ -n "$token_url" ]; then
    echo "请在浏览器中获取你的 ${key_label}："
    echo "  $token_url"
  else
    echo "请在浏览器中获取你的 ${key_label}（站点未知或保持不变）。"
  fi

  local input=""
  if [ -n "${existing:-}" ]; then
    input="$(read_secret_tty "粘贴你的 ${key_label}（直接回车保持不变），输入隐藏: ")"
  else
    input="$(read_secret_tty "粘贴你的 ${key_label}，然后按 Enter（输入隐藏）: ")"
  fi
  input="$(trim "$input")"
  # strip any CR/LF inside
  input="$(printf '%s' "$input" | tr -d '\r\n')"

  KEPT_KEY=false
  if [ -z "$input" ]; then
    if [ -n "${existing:-}" ]; then
      KEPT_KEY=true
      NEW_API_KEY="$existing"
    else
      echo "ERROR: ${key_label} 不能为空。" >&2
      exit 1
    fi
  else
    NEW_API_KEY="$input"
  fi
}

# -------- Factory Droid CLI --------
setup_factory() {
  echo
  echo "=== 配置 Factory Droid CLI (~/.factory/config.json) ==="
  local FACTORY_DIR="$HOME/.factory"
  local FACTORY_CFG="$FACTORY_DIR/config.json"
  mkdir -p "$FACTORY_DIR"

  # Read existing values
  local existing_base="" existing_key=""
  if [ -f "$FACTORY_CFG" ]; then
    if has_cmd jq && jq -e . "$FACTORY_CFG" >/dev/null 2>&1; then
      existing_base="$(jq -r '.custom_models[0].base_url // empty' "$FACTORY_CFG")"
      existing_key="$(jq -r '.custom_models[0].api_key // empty' "$FACTORY_CFG")"
    else
      existing_base="$(sed -n 's/.*"base_url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$FACTORY_CFG" | head -n1 || true)"
      existing_key="$(sed -n 's/.*"api_key"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$FACTORY_CFG" | head -n1 || true)"
    fi
  fi

  select_site "Factory Droid CLI" "/v1" "$existing_base"
  prompt_api_key "OPENAI_API_KEY" "$existing_key" "$TOKEN_URL"

  local base_to_write key_to_write
  if [ "$KEPT_BASE" = true ]; then base_to_write="$existing_base"; else base_to_write="$NEW_BASE_URL"; fi
  if [ "$KEPT_KEY" = true ]; then key_to_write="$existing_key"; else key_to_write="$NEW_API_KEY"; fi

  # Build custom_models array using jq if available for strict JSON (prevents formatting issues)
  local tmp_new tmp_merged
  tmp_new="$(mktemp)"

  if has_cmd jq; then
    jq -n --arg base "$base_to_write" --arg key "$key_to_write" '
      def m($name;$model):
        { "model_display_name": $name,
          "model": $model,
          "base_url": $base,
          "api_key": $key,
          "provider": "openai",
          "max_tokens": 128000 };
      { "custom_models": [
          m("GPT-5 [Zeta]"; "gpt-5"),
          m("GPT-5.1 High [Zeta]"; "gpt-5.1-high"),
          m("GPT-5.1-Codex [Zeta]"; "gpt-5-codex"),
          m("GPT-5.1-Codex Mini [Zeta]"; "gpt-5.1-codex-mini"),
          m("GPT-5-mini [Zeta]"; "gpt-5-mini"),
          m("GPT-5-mini High [Zeta]"; "gpt-5-mini-high")
        ] }' > "$tmp_new"
  else
    # Fallback: write plain JSON (no extra commas, no line breaks inside values)
    local key_json base_json
    key_json="$(json_escape "$key_to_write")"
    base_json="$(json_escape "$base_to_write")"
    cat > "$tmp_new" <<EOF
{
  "custom_models": [
    {
      "model_display_name": "GPT-5.1 [Zeta]",
      "model": "gpt-5.1",
      "base_url": "$base_json",
      "api_key": "$key_json",
      "provider": "openai",
      "max_tokens": 128000
    },
    {
      "model_display_name": "GPT-5.1 High [Zeta]",
      "model": "gpt-5.1-high",
      "base_url": "$base_json",
      "api_key": "$key_json",
      "provider": "openai",
      "max_tokens": 128000
    },
    {
      "model_display_name": "GPT-5.1-Codex [Zeta]",
      "model": "gpt-5.1-codex",
      "base_url": "$base_json",
      "api_key": "$key_json",
      "provider": "openai",
      "max_tokens": 128000
    },
    {
      "model_display_name": "GPT-5.1-Codex Mini [Zeta]",
      "model": "gpt-5.1-codex-mini",
      "base_url": "$base_json",
      "api_key": "$key_json",
      "provider": "openai",
      "max_tokens": 128000
    },
    {
      "model_display_name": "GPT-5-mini [Zeta]",
      "model": "gpt-5-mini",
      "base_url": "$base_json",
      "api_key": "$key_json",
      "provider": "openai",
      "max_tokens": 128000
    },
    {
      "model_display_name": "GPT-5-mini High [Zeta]",
      "model": "gpt-5-mini-high",
      "base_url": "$be",
      "api_key": "$ke",
      "provider": "openai",
      "max_tokens": 128000
    }
    },
    {
      "model_display_name": "Gemini-3 Preview [Zeta]",
      "model": "gemini-3-pro-preview",
      "base_url": "$be",
      "api_key": "$ke",
      "provider": "generic-chat-completion-api",
      "max_tokens": 65500
    }
  ]
}
EOF
  fi

  if [ -f "$FACTORY_CFG" ] && has_cmd jq && jq -e . "$FACTORY_CFG" >/dev/null 2>&1; then
    tmp_merged="$(mktemp)"
    # Merge: existing object * new_custom_models (override only custom_models)
    jq -s '.[0] * .[1]' "$FACTORY_CFG" "$tmp_new" > "$tmp_merged"
    cp "$FACTORY_CFG" "$FACTORY_CFG.bak.$(timestamp)" || true
    mv "$tmp_merged" "$FACTORY_CFG"
    rm -f "$tmp_new"
  else
    if [ -f "$FACTORY_CFG" ]; then
      cp "$FACTORY_CFG" "$FACTORY_CFG.bak.$(timestamp)" || true
      echo "注意：未检测到 jq 或现有 JSON 非法，将覆盖 $FACTORY_CFG（已创建备份）。"
    fi
    mv "$tmp_new" "$FACTORY_CFG"
  fi

  chmod 700 "$FACTORY_DIR" || true
  chmod 600 "$FACTORY_CFG" || true

  echo "✅ Factory Droid CLI 已配置："
  echo "  配置文件: $FACTORY_CFG"
  if [ "$KEPT_BASE" = true ]; then echo "  base_url: 保持不变 ($existing_base)"; else echo "  base_url: $base_to_write ($SITE_NAME)"; fi
  if [ "$KEPT_KEY" = true ]; then echo "  API Key: 保持不变"; else echo "  API Key: 已更新"; fi

  # Quick validate hint (optional)
  if has_cmd jq; then
    if ! jq -e . "$FACTORY_CFG" >/dev/null 2>&1; then
      echo "警告：写入后 JSON 验证失败，请手动检查 $FACTORY_CFG" >&2
    fi
  fi
}

# -------- OpenAI Codex CLI --------
setup_codex() {
  echo
  echo "=== 配置 OpenAI Codex CLI (~/.codex) ==="

  local COD_DIR="$HOME/.codex"
  local CONFIG_FILE="$COD_DIR/config.toml"
  local AUTH_FILE="$COD_DIR/auth.json"

  local existing_base="" existing_key=""
  if [ -f "$CONFIG_FILE" ]; then
    existing_base="$(sed -n 's/^[[:space:]]*base_url[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$CONFIG_FILE" | head -n1 || true)"
  fi
  if [ -f "$AUTH_FILE" ]; then
    existing_key="$(sed -n 's/^[[:space:]]*"OPENAI_API_KEY"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$AUTH_FILE" | head -n1 || true)"
  fi

  select_site "OpenAI Codex CLI" "/v1" "$existing_base"
  prompt_api_key "OPENAI_API_KEY" "$existing_key" "$TOKEN_URL"

  local base_to_write key_to_write
  if [ "$KEPT_BASE" = true ]; then base_to_write="$existing_base"; else base_to_write="$NEW_BASE_URL"; fi
  if [ "$KEPT_KEY" = true ]; then key_to_write="$existing_key"; else key_to_write="$NEW_API_KEY"; fi
  key_to_write="$(printf '%s' "$key_to_write" | tr -d '\r\n')"

  mkdir -p "$COD_DIR"

  cat > "$CONFIG_FILE" <<EOF
model = "gpt-5-codex"
model_provider = "zetatechs"
model_reasoning_effort = "medium"
disable_response_storage = true

[model_providers.zetatechs]
name = "zetatechs"
base_url = "$base_to_write"
wire_api = "responses"
EOF

  local key_json; key_json="$(json_escape "$key_to_write")"
  cat > "$AUTH_FILE" <<EOF
{
  "OPENAI_API_KEY": "$key_json"
}
EOF

  chmod 700 "$COD_DIR" || true
  chmod 600 "$CONFIG_FILE" "$AUTH_FILE" || true

  echo "✅ OpenAI Codex CLI 已配置："
  echo "  配置文件: $CONFIG_FILE"
  echo "  凭据文件: $AUTH_FILE"
  if [ "$KEPT_BASE" = true ]; then echo "  站点: 保持不变 ($existing_base)"; else echo "  站点: $base_to_write ($SITE_NAME)"; fi
  if [ "$KEPT_KEY" = true ]; then echo "  API Key: 保持不变"; else echo "  API Key: 已更新"; fi
}

# -------- Anthropic Claude Code CLI --------
setup_anthropic() {
  echo
  echo "=== 配置 Anthropic Claude Code CLI (环境变量写入 ~/.bashrc / ~/.zshrc) ==="

  local existing_base existing_key
  existing_base="$(read_env_from_rcs "ANTHROPIC_BASE_URL")"
  existing_key="$(read_env_from_rcs "ANTHROPIC_AUTH_TOKEN")"

  # Anthropic 默认不加 /v1，若你需要可手动自定义选择 4
  select_site "Anthropic Claude Code CLI" "" "$existing_base"
  prompt_api_key "ANTHROPIC_AUTH_TOKEN" "$existing_key" "$TOKEN_URL"

  local base_to_write="" key_to_write=""
  if [ "$KEPT_BASE" = false ]; then base_to_write="$NEW_BASE_URL"; fi
  if [ "$KEPT_KEY" = false ]; then key_to_write="$NEW_API_KEY"; fi

  # Upsert to RC files; if user kept existing values, we don't touch them
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -n "$base_to_write" ]; then upsert_export "$rc" "ANTHROPIC_BASE_URL" "$base_to_write"; fi
    if [ -n "$key_to_write" ]; then upsert_export "$rc" "ANTHROPIC_AUTH_TOKEN" "$key_to_write"; fi
  done

  echo "✅ Anthropic Claude Code CLI 配置完成。"
  if [ "$KEPT_BASE" = true ]; then echo "  ANTHROPIC_BASE_URL: 保持不变 (${existing_base:-未检测到})"; else echo "  ANTHROPIC_BASE_URL: ${base_to_write} ($SITE_NAME)"; fi
  if [ "$KEPT_KEY" = true ]; then echo "  ANTHROPIC_AUTH_TOKEN: 保持不变"; else echo "  ANTHROPIC_AUTH_TOKEN: 已更新"; fi
  echo
  echo "提示：请执行以下命令之一让环境变量立即生效，或重新打开终端："
  echo "  source ~/.bashrc    # bash"
  echo "  source ~/.zshrc     # zsh"
}

# -------- Main --------
echo "=== Zetatechs Coding CLI 配置向导 ==="
echo
echo "请选择要配置的应用："
echo "  1) Factory Droid CLI"
echo "  2) OpenAI Codex CLI"
echo "  3) Anthropic Claude Code CLI"

app_choice="$(read_tty "输入选项 [1/2/3] (默认 1): ")"
app_choice="${app_choice:-1}"

case "$app_choice" in
  1) setup_factory ;;
  2) setup_codex ;;
  3) setup_anthropic ;;
  *) echo "无效选项：$app_choice" >&2; exit 1 ;;
esac

echo
echo "完成。再次运行本脚本时："
echo "- 如不选择站点或不输入 API Key，将保持现有配置不变（不会清空）。"
