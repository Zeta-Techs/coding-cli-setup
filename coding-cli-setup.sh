#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# coding-cli-setup.sh — Interactive setup for multiple coding CLIs on Linux/macOS
# Supports:
#   1) OpenCode CLI (~/.config/opencode/opencode.json)
#   2) OpenAI Codex CLI (~/.codex/config.toml + ~/.codex/auth.json)
#   3) Anthropic Claude Code CLI (ANTHROPIC_* envs in ~/.bashrc / ~/.zshrc)
#   4) Factory Droid CLI (~/.factory/config.json)
#

# 站点选项（每个应用内均提供）：
#   1) ZetaTechs API 主站:   https://api.zetatechs.com(/v1)
#   2) ZetaTechs API 企业站: https://ent.zetatechs.com(/v1)
#   3) ZetaTechs API Codex站: https://codex.zetatechs.com(/v1)
#   4) 自定义: 手动输入 base_url（会给出 1 号站点作为格式示例）
#
# 行为说明：
# - 再次运行时若直接回车不选择站点/不输入必要信息，将保持原值不变。
# - 对于 OpenCode：脚本不写入 API Key，请在 OpenCode 内使用 /connect 配置。
# - 推荐安装 jq 以确保写入合法 JSON。
#
# Copyright (c) 2025

set -Eeuo pipefail
umask 077

# Ensure interactive terminal when piped
if ! [ -t 0 ] && ! [ -t 1 ] && ! [ -t 2 ]; then
  echo "ERROR: No interactive terminal detected. Please run in a terminal." >&2
  exit 1
fi

# -------- Utils --------
trim() {
  # Trim leading/trailing whitespace
  local s="${1:-}"
  s="${s#${s%%[![:space:]]*}}"
  s="${s%${s##*[![:space:]]}}"
  printf "%s" "$s"
}

has_cmd() { command -v "$1" >/dev/null 2>&1; }

read_tty() {
  local __p="${1:-}" input
  # Read from /dev/tty when an interactive terminal exists (curl | bash safe)
  if [ -t 1 ] && [ -r /dev/tty ] && [ -w /dev/tty ]; then
    read -r -p "$__p" input < /dev/tty || true
  else
    read -r -p "$__p" input || true
  fi
  printf "%s" "${input:-}"
}

read_secret_tty() {
  local __p="${1:-}" input
  if [ -t 1 ] && [ -r /dev/tty ] && [ -w /dev/tty ]; then
    read -r -s -p "$__p" input < /dev/tty || true
  else
    read -r -s -p "$__p" input || true
  fi
  echo
  printf "%s" "${input:-}"
}

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

ensure_trailing_path() {
  # Args: base_url desired_path
  # Examples:
  #   ensure_trailing_path "https://api.zetatechs.com" "/v1" -> https://api.zetatechs.com/v1
  #   ensure_trailing_path "https://api.zetatechs.com/v1/" "/v1" -> https://api.zetatechs.com/v1
  local base="${1:-}" desired="${2:-}"
  base="$(trim "$base")"
  desired="$(trim "$desired")"
  [ -z "$base" ] && { printf "%s" ""; return 0; }
  [ -z "$desired" ] && { printf "%s" "$base"; return 0; }

  # Drop trailing slash from base
  base="${base%/}"

  # If base already ends with desired, keep as-is
  case "$base" in
    *"$desired") printf "%s" "$base" ;;
    *) printf "%s%s" "$base" "$desired" ;;
  esac
}

strip_opencode_known_suffix() {
  # Remove a trailing /v1 or /v1beta (if present)
  local base="${1:-}"
  base="$(trim "$base")"
  base="${base%/}"
  case "$base" in
    */v1beta) printf "%s" "${base%/v1beta}" ;;
    */v1) printf "%s" "${base%/v1}" ;;
    *) printf "%s" "$base" ;;
  esac
}

read_opencode_provider_base() {
  # OpenCode provider base name (provider group prefix)
  local default="${1:-}"
  local val
  echo >&2
  echo "OpenCode 需要一个 provider 前缀用于生成 provider id：" >&2
  echo "  示例：zetatechs-api -> zetatechs-api-openai / zetatechs-api-claude / zetatechs-api-gemini" >&2
  if [ -n "$default" ]; then
    echo "提示：按 Enter 使用默认值（当前/默认: ${default}）" >&2
    val="$(read_tty "请输入 provider 前缀（provider-base）: ")"
    val="$(trim "$val")"
    if [ -z "$val" ]; then printf "%s" "$default"; return 0; fi
  else
    val="$(read_tty "请输入 provider 前缀（provider-base）: ")"
    val="$(trim "$val")"
    if [ -z "$val" ]; then
      echo "ERROR: provider 前缀不能为空。" >&2
      exit 1
    fi
  fi
  printf "%s" "$val"
}

build_opencode_template() {
  # Args: provider_base site_label base_v1 base_v1beta
  local pbase="${1:-}" site_label="${2:-}" base_v1="${3:-}" base_v1beta="${4:-}"

  local openai_id="${pbase}-openai" claude_id="${pbase}-claude" gemini_id="${pbase}-gemini"
  local base_v1_json base_v1beta_json
  base_v1_json="$(json_escape "$base_v1")"
  base_v1beta_json="$(json_escape "$base_v1beta")"

  cat <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "provider": {
    "${openai_id}": {
      "npm": "@ai-sdk/openai",
      "name": "${site_label} OpenAI",
      "options": {
        "baseURL": "${base_v1_json}"
      },
      "models": {
        "gpt-5.2": {
          "name": "GPT-5.2",
          "options": {
            "reasoningSummary": "auto",
            "include": ["reasoning.encrypted_content"]
          },
          "variants": {
            "minimal": { "reasoningEffort": "minimal", "textVerbosity": "low" },
            "low": { "reasoningEffort": "low", "textVerbosity": "low" },
            "medium": { "reasoningEffort": "medium", "textVerbosity": "medium" },
            "high": { "reasoningEffort": "high", "textVerbosity": "high" },
            "xhigh": { "reasoningEffort": "xhigh", "textVerbosity": "high" }
          }
        },
        "gpt-5.2-codex": {
          "name": "GPT-5.2-Codex",
          "options": {
            "reasoningSummary": "auto",
            "textVerbosity": "medium",
            "include": ["reasoning.encrypted_content"]
          },
          "variants": {
            "low": { "reasoningEffort": "low" },
            "medium": { "reasoningEffort": "medium" },
            "high": { "reasoningEffort": "high" },
            "xhigh": { "reasoningEffort": "xhigh" }
          }
        },
        "gpt-5.1": {
          "name": "GPT-5.1",
          "options": {
            "reasoningSummary": "auto",
            "include": ["reasoning.encrypted_content"]
          },
          "variants": {
            "none": { "reasoningEffort": "none", "textVerbosity": "low" },
            "minimal": { "reasoningEffort": "minimal", "textVerbosity": "low" },
            "low": { "reasoningEffort": "low", "textVerbosity": "low" },
            "medium": { "reasoningEffort": "medium", "textVerbosity": "medium" },
            "high": { "reasoningEffort": "high", "textVerbosity": "high" },
            "xhigh": { "reasoningEffort": "xhigh", "textVerbosity": "high" }
          }
        },
        "gpt-5.1-codex-max": {
          "name": "GPT-5.1-Codex-Max",
          "options": {
            "reasoningSummary": "auto",
            "textVerbosity": "medium",
            "include": ["reasoning.encrypted_content"]
          },
          "variants": {
            "low": { "reasoningEffort": "low" },
            "medium": { "reasoningEffort": "medium" },
            "high": { "reasoningEffort": "high" }
          }
        },
        "gpt-5.1-codex": {
          "name": "GPT-5.1-Codex",
          "options": {
            "reasoningSummary": "auto",
            "textVerbosity": "medium",
            "include": ["reasoning.encrypted_content"]
          },
          "variants": {
            "low": { "reasoningEffort": "low" },
            "medium": { "reasoningEffort": "medium" },
            "high": { "reasoningEffort": "high" }
          }
        },
        "gpt-5.1-codex-mini": {
          "name": "GPT-5.1-Codex-Mini",
          "options": {
            "reasoningSummary": "auto",
            "textVerbosity": "medium",
            "include": ["reasoning.encrypted_content"]
          },
          "variants": {
            "low": { "reasoningEffort": "low" },
            "medium": { "reasoningEffort": "medium" },
            "high": { "reasoningEffort": "high" }
          }
        },
        "gpt-5": {
          "name": "GPT-5",
          "options": {
            "reasoningSummary": "auto",
            "include": ["reasoning.encrypted_content"]
          },
          "variants": {
            "minimal": { "reasoningEffort": "minimal", "textVerbosity": "low" },
            "low": { "reasoningEffort": "low", "textVerbosity": "low" },
            "medium": { "reasoningEffort": "medium", "textVerbosity": "medium" },
            "high": { "reasoningEffort": "high", "textVerbosity": "high" }
          }
        },
        "gpt-5-codex": {
          "name": "GPT-5-Codex",
          "options": {
            "reasoningSummary": "auto",
            "textVerbosity": "medium",
            "include": ["reasoning.encrypted_content"]
          },
          "variants": {
            "low": { "reasoningEffort": "low" },
            "medium": { "reasoningEffort": "medium" },
            "high": { "reasoningEffort": "high" }
          }
        }
      }
    },

    "${claude_id}": {
      "npm": "@ai-sdk/anthropic",
      "name": "${site_label} Claude",
      "options": {
        "baseURL": "${base_v1_json}"
      },
      "models": {
        "claude-haiku-4-5-20251001": { "name": "Claude-Haiku-4-5-20251001" },
        "claude-opus-4-5-20251101": { "name": "Claude-Opus-4-5-20251101" },
        "claude-opus-4-5-20251101-thinking": { "name": "Claude-Opus-4-5-20251101-thinking" },
        "claude-sonnet-4-5-20250929": { "name": "Claude-Sonnet-4-5-20250929" },
        "claude-sonnet-4-5-20250929-thinking": { "name": "Claude-Sonnet-4-5-20250929-thinking" }
      }
    },

    "${gemini_id}": {
      "npm": "@ai-sdk/google",
      "name": "${site_label} Gemini",
      "options": {
        "baseURL": "${base_v1beta_json}"
      },
      "models": {
        "gemini-3-pro-preview": { "name": "Gemini 3 Pro Preview" },
        "gemini-3-flash-preview": { "name": "Gemini 3 Flash Preview" }
      }
    }
  }
}
EOF
}

upsert_opencode_provider_baseurl_jq() {
  # Args: cfg provider_id base_url
  local cfg="${1:-}" pid="${2:-}" base="${3:-}"
  local tmp
  tmp="$(mktemp)"
  jq --arg pid "$pid" --arg base "$base" '
    .provider = (.provider // {})
    | .provider[$pid] = (.provider[$pid] // {})
    | .provider[$pid].options = (.provider[$pid].options // {})
    | .provider[$pid].options.baseURL = $base
  ' "$cfg" > "$tmp"
  cp "$cfg" "$cfg.bak.$(timestamp)" || true
  mv "$tmp" "$cfg"
}

merge_opencode_provider_group_jq() {
  # Merge a full provider template for a group, then set baseURLs.
  # - Does NOT write apiKey
  # - Does NOT overwrite existing provider blocks (preserves models / apiKey)
  # Args: cfg provider_base site_label base_v1 base_v1beta
  local cfg="${1:-}" pbase="${2:-}" site_label="${3:-}" base_v1="${4:-}" base_v1beta="${5:-}"
  local tmpl tmp
  tmpl="$(mktemp)"
  tmp="$(mktemp)"

  build_opencode_template "$pbase" "$site_label" "$base_v1" "$base_v1beta" > "$tmpl"

  local openai_id="${pbase}-openai" claude_id="${pbase}-claude" gemini_id="${pbase}-gemini"

  jq --slurpfile t "$tmpl" \
    --arg openai "$openai_id" \
    --arg claude "$claude_id" \
    --arg gemini "$gemini_id" \
    --arg baseV1 "$base_v1" \
    --arg baseV1b "$base_v1beta" '
      .["$schema"] = (.["$schema"] // $t[0]["$schema"])
      | .provider = (.provider // {})
      | .provider[$openai] = (.provider[$openai] // $t[0].provider[$openai])
      | .provider[$claude] = (.provider[$claude] // $t[0].provider[$claude])
      | .provider[$gemini] = (.provider[$gemini] // $t[0].provider[$gemini])
      | .provider[$openai].options = (.provider[$openai].options // {})
      | .provider[$claude].options = (.provider[$claude].options // {})
      | .provider[$gemini].options = (.provider[$gemini].options // {})
      | .provider[$openai].options.baseURL = $baseV1
      | .provider[$claude].options.baseURL = $baseV1
      | .provider[$gemini].options.baseURL = $baseV1b
    ' "$cfg" > "$tmp"

  cp "$cfg" "$cfg.bak.$(timestamp)" || true
  mv "$tmp" "$cfg"
  rm -f "$tmpl" || true
}

setup_opencode() {
  echo
  echo "=== 配置 OpenCode (~/.config/opencode/opencode.json) ==="

  local OPENCODE_DIR="$HOME/.config/opencode"
  local OPENCODE_CFG="$OPENCODE_DIR/opencode.json"
  mkdir -p "$OPENCODE_DIR"

  # Try to infer existing provider base + baseURL.
  # Prefer known provider ids; otherwise fall back to any provider ending with "-openai".
  local existing_base_v1="" existing_provider_base="" existing_providers="" provider_base=""
  local known_id_main_openai="zetatechs-api-openai"
  local known_id_ent_openai="zetatechs-api-enterprise-openai"

  if [ -f "$OPENCODE_CFG" ] && has_cmd jq && jq -e . "$OPENCODE_CFG" >/dev/null 2>&1; then
    local existing_openai_id=""

    existing_base_v1="$(jq -r --arg id "$known_id_main_openai" '.provider[$id].options.baseURL // empty' "$OPENCODE_CFG")"
    if [ -n "$existing_base_v1" ]; then
      existing_openai_id="$known_id_main_openai"
    else
      existing_base_v1="$(jq -r --arg id "$known_id_ent_openai" '.provider[$id].options.baseURL // empty' "$OPENCODE_CFG")"
      if [ -n "$existing_base_v1" ]; then
        existing_openai_id="$known_id_ent_openai"
      fi
    fi

    if [ -z "$existing_openai_id" ]; then
      existing_openai_id="$(jq -r '.provider | keys[]? | select(test("-openai$"))' "$OPENCODE_CFG" 2>/dev/null | head -n1 || true)"
      if [ -n "$existing_openai_id" ]; then
        existing_base_v1="$(jq -r --arg id "$existing_openai_id" '.provider[$id].options.baseURL // empty' "$OPENCODE_CFG")"
      fi
    fi

    if [ -n "$existing_openai_id" ]; then
      existing_provider_base="${existing_openai_id%-openai}"
    fi

    existing_providers="$(jq -r '.provider | keys[]?' "$OPENCODE_CFG" 2>/dev/null || true)"
  fi

  # For OpenCode, the selected site defines baseURL endings:
  # - OpenAI/Claude: /v1
  # - Gemini: /v1beta
  # We prompt once and derive both URLs.
  local existing_site_hint
  existing_site_hint="$(strip_opencode_known_suffix "$existing_base_v1")"
  select_site "OpenCode" "" "$existing_site_hint"
  local selected_site_name="$SITE_NAME"

  # Derive /v1 and /v1beta from selected base.
  local selected_base_raw
  if [ "$KEPT_BASE" = true ]; then
    # existing_base_v1 might already include /v1
    selected_base_raw="$existing_base_v1"
    if [ -z "$selected_base_raw" ]; then
      selected_base_raw="$NEW_BASE_URL"
    fi
  else
    selected_base_raw="$NEW_BASE_URL"
  fi

  local base_root base_v1 base_v1beta
  base_root="$(strip_opencode_known_suffix "$selected_base_raw")"
  base_v1="$(ensure_trailing_path "$base_root" "/v1")"
  base_v1beta="$(ensure_trailing_path "$base_root" "/v1beta")"

  # Provider group management: add vs update
  local mode=""
  if [ -n "$existing_providers" ]; then
    echo
    echo "OpenCode provider 配置模式："
    echo "  1) 添加 provider group（新增一组 provider 前缀）"
    echo "  2) 更新 provider group（选择现有 provider 前缀并更新 baseURL）"
    mode="$(read_tty "输入选项 [1/2] (默认 2): ")"
    mode="${mode:-2}"
  else
    mode="1"
  fi

  # Detect existing provider groups from IDs: <base>-openai/-claude/-gemini
  local existing_groups=""
  if [ -n "$existing_providers" ]; then
    existing_groups="$(printf '%s\n' "$existing_providers" | sed -n 's/\(.*\)-\(openai\|claude\|gemini\)$/\1/p' | sort -u)"
  fi

  if [ "$mode" = "1" ]; then
    # Suggest a default base derived from the selected site
    local default_base=""
    if [ "$selected_site_name" = "主站" ]; then default_base="zetatechs-api";
    elif [ "$selected_site_name" = "企业站" ]; then default_base="zetatechs-api-enterprise";
    elif [ -n "$existing_provider_base" ]; then default_base="$existing_provider_base";
    else default_base=""; fi

    provider_base="$(read_opencode_provider_base "$default_base")"
  elif [ "$mode" = "2" ]; then
    if [ -z "$existing_groups" ]; then
      echo "ERROR: 未检测到可更新的 provider group。" >&2
      exit 1
    fi
    echo
    echo "已检测到 provider groups："
    printf '%s\n' "$existing_groups" | nl -w2 -s') '
    local idx
    idx="$(read_tty "选择要更新的 group 序号 (默认 1): ")"
    idx="${idx:-1}"
    provider_base="$(printf '%s\n' "$existing_groups" | sed -n "${idx}p")"
    provider_base="$(trim "$provider_base")"
    if [ -z "$provider_base" ]; then
      echo "ERROR: 无效选择。" >&2
      exit 1
    fi
  else
    echo "无效选项：$mode" >&2
    exit 1
  fi

  local site_label="ZetaTechs ${selected_site_name}"
  if [ "$selected_site_name" = "保持不变" ]; then
    if [ -n "$existing_site_hint" ]; then
      site_label="ZetaTechs ${existing_site_hint}"
    else
      site_label="ZetaTechs"
    fi
  fi

  # OpenCode 不在脚本中填写 API Key。
  # 请在 OpenCode 内执行 /connect，选择 provider 并填写 Key。

  # If file missing, always create full template
  if [ ! -f "$OPENCODE_CFG" ]; then
    build_opencode_template "$provider_base" "$site_label" "$base_v1" "$base_v1beta" > "$OPENCODE_CFG"
  else
    if has_cmd jq && jq -e . "$OPENCODE_CFG" >/dev/null 2>&1; then
      # Ensure the selected group exists; preserve existing provider blocks if already present.
      merge_opencode_provider_group_jq "$OPENCODE_CFG" "$provider_base" "$site_label" "$base_v1" "$base_v1beta"
    else
      echo "注意：未检测到 jq 或现有 JSON 非法，无法安全合并。"
      echo "为避免误覆盖你的 OpenCode 配置，请安装 jq 后重试，或手工编辑：$OPENCODE_CFG"
      exit 1
    fi
  fi

  # Reload provider list after changes
  local providers_after=""
  if has_cmd jq && jq -e . "$OPENCODE_CFG" >/dev/null 2>&1; then
    providers_after="$(jq -r '.provider | keys[]?' "$OPENCODE_CFG" 2>/dev/null || true)"
  fi


  chmod 700 "$OPENCODE_DIR" || true
  chmod 600 "$OPENCODE_CFG" || true

  echo "✅ OpenCode 已配置："
  echo "  配置文件: $OPENCODE_CFG"
  echo "  当前 provider group: ${provider_base}"
  echo "  baseURL (OpenAI/Claude): $base_v1"
  echo "  baseURL (Gemini): $base_v1beta"
  echo "  提示：请在 OpenCode 内执行 /connect，选择对应 provider 并填写 API Key。"

  if [ -n "$providers_after" ]; then
    echo
    echo "  当前 providers："
    printf '%s\n' "$providers_after" | sed 's/^/  - /'
  fi

  # Optional deletion (group-based)
  if [ -n "$providers_after" ] && has_cmd jq && jq -e . "$OPENCODE_CFG" >/dev/null 2>&1; then
    local del
    del="$(read_tty "是否删除某个 provider group？输入 y 删除，其它跳过 [y/N]: ")"
    del="$(trim "$del")"
    if [ "$del" = "y" ] || [ "$del" = "Y" ]; then
      local groups_after
      groups_after="$(printf '%s\n' "$providers_after" | sed -n 's/\(.*\)-\(openai\|claude\|gemini\)$/\1/p' | sort -u)"
      if [ -z "$groups_after" ]; then
        echo "未检测到可删除的 provider group。"
      else
        echo
        echo "可删除的 provider groups："
        printf '%s\n' "$groups_after" | nl -w2 -s') '
        local del_idx del_base
        del_idx="$(read_tty "选择要删除的 group 序号 (默认 1): ")"
        del_idx="${del_idx:-1}"
        del_base="$(printf '%s\n' "$groups_after" | sed -n "${del_idx}p")"
        del_base="$(trim "$del_base")"
        if [ -z "$del_base" ]; then
          echo "无效选择，已跳过删除。"
        else
          local del_confirm
          del_confirm="$(read_tty "确认删除 group '${del_base}' 及其 3 个 providers？输入 DELETE 确认: ")"
          if [ "$(trim "$del_confirm")" = "DELETE" ]; then
            cp "$OPENCODE_CFG" "$OPENCODE_CFG.bak.$(timestamp)" || true
            local tmp
            tmp="$(mktemp)"
            jq --arg base "$del_base" '
              .provider = (.provider // {})
              | del(.provider[(($base)+"-openai")])
              | del(.provider[(($base)+"-claude")])
              | del(.provider[(($base)+"-gemini")])
            ' "$OPENCODE_CFG" > "$tmp"
            mv "$tmp" "$OPENCODE_CFG"
            chmod 600 "$OPENCODE_CFG" || true
            echo "已删除 provider group: $del_base"
            local providers_final
            providers_final="$(jq -r '.provider | keys[]?' "$OPENCODE_CFG" 2>/dev/null || true)"
            if [ -n "$providers_final" ]; then
              echo "当前 providers："
              printf '%s\n' "$providers_final" | sed 's/^/  - /'
            else
              echo "当前 providers：<empty>"
            fi
          else
            echo "未确认 DELETE，已跳过删除。"
          fi
        fi
      fi
    fi
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
      "base_url": "$base_json",
      "api_key": "$key_json",
      "provider": "openai",
      "max_tokens": 128000
    },
    {
      "model_display_name": "Gemini-3 Preview [Zeta]",
      "model": "gemini-3-pro-preview",
      "base_url": "$base_json",
      "api_key": "$key_json",
      "provider": "generic-chat-completion-api",
      "max_tokens": 60000
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
  echo "  1) OpenCode"
  echo "  2) OpenAI Codex CLI"
  echo "  3) Anthropic Claude Code CLI"
  echo "  4) Factory Droid CLI"

  app_choice="$(read_tty "输入选项 [1/2/3/4] (默认 1): ")"
  app_choice="${app_choice:-1}"

  case "$app_choice" in
    1) setup_opencode ;;
    2) setup_codex ;;
    3) setup_anthropic ;;
    4) setup_factory ;;
    *) echo "无效选项：$app_choice" >&2; exit 1 ;;
  esac


echo
echo "完成。再次运行本脚本时："
echo "- 如不选择站点或不输入必要信息，将保持现有配置不变（不会清空）。"
