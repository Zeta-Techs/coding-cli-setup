param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Ensure-Scheme([string]$url) {
  if ($url -match '^(?i)https?://') { return $url }
  return "https://$url"
}

function Extract-Host([string]$url) {
  try {
    if ($url -notmatch '^(?i)https?://') { $url = "https://$url" }
    return ([Uri]$url).Host
  } catch { return '' }
}

function Timestamp() { (Get-Date).ToString('yyyyMMdd-HHmmss') }

function Read-Trim([string]$prompt, [string]$default='') {
  $v = Read-Host $prompt
  if ([string]::IsNullOrWhiteSpace($v)) { return $default }
  return $v.Trim()
}

function Read-Secret([string]$prompt) {
  $sec = Read-Host -AsSecureString $prompt
  if (-not $sec) { return '' }
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
  try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

function Json-Escape([string]$s) {
  if ($null -eq $s) { return '' }
  $s = $s -replace '\\', '\\\\'
  $s = $s -replace '"', '\\"'
  $s = $s -replace "`r", '\\r'
  $s = $s -replace "`n", '\\n'
  $s = $s -replace "`t", '\\t'
  return $s
}

function Select-Site([string]$AppLabel, [string]$BaseSuffix, [string]$ExistingBase) {
  $example = "https://api.zetatechs.com$BaseSuffix"
  Write-Host
  Write-Host "请选择 $AppLabel API 站点："
  Write-Host "  1) ZetaTechs API 主站:   $example"
  Write-Host "  2) ZetaTechs API 企业站: https://ent.zetatechs.com$BaseSuffix"
  Write-Host "  3) ZetaTechs API Codex站: https://codex.zetatechs.com$BaseSuffix"
  Write-Host "  4) 自定义: 手动输入 base_url（示例: $example）"

  $choice = ''
  $kept = $false
  if ($ExistingBase) {
    $choice = Read-Trim "输入选项 [1/2/3/4]，或直接回车保持不变" ''
    if (-not $choice) {
      $kept = $true
      $base = $ExistingBase
      $apiHost = Extract-Host $base
      $token = if ($apiHost) { "https://$apiHost/console/token" } else { '' }
      return [pscustomobject]@{ BaseUrl=$base; TokenUrl=$token; KeptBase=$true; SiteName='保持不变' }
    }
  } else {
    $choice = Read-Trim "输入选项 [1/2/3/4] (默认 1)" '1'
  }

  $apiHost = ''
  $siteName = ''
  switch ($choice) {
    '1' { $apiHost='api.zetatechs.com'; $siteName='主站' }
    '2' { $apiHost='ent.zetatechs.com'; $siteName='企业站' }
    '3' { $apiHost='codex.zetatechs.com'; $siteName='Codex站' }
    '4' {
      $siteName='自定义'
      Write-Host
      Write-Host "请输入完整 base_url（以 http(s):// 开头）。"
      Write-Host "示例: $example"
      $custom = Read-Trim "自定义 base_url" ''
      if (-not $custom) { throw 'base_url 不能为空' }
      $base = Ensure-Scheme $custom
      $apiHost = Extract-Host $base
      $token = if ($apiHost) { "https://$apiHost/console/token" } else { '' }
      return [pscustomobject]@{ BaseUrl=$base; TokenUrl=$token; KeptBase=$false; SiteName=$siteName }
    }
    Default { throw "无效选项：$choice" }
  }

  $baseUrl = "https://$apiHost$BaseSuffix"
  $tokenUrl = "https://$apiHost/console/token"
  [pscustomobject]@{ BaseUrl=$baseUrl; TokenUrl=$tokenUrl; KeptBase=$false; SiteName=$siteName }
}

function Prompt-ApiKey([string]$KeyLabel, [string]$Existing, [string]$TokenUrl) {
  Write-Host
  if ($TokenUrl) { Write-Host "请在浏览器中获取你的 $KeyLabel：`n  $TokenUrl" }
  else { Write-Host "请在浏览器中获取你的 $KeyLabel（站点未知或保持不变）。" }

  if ($Existing) {
    $input = Read-Secret "粘贴你的 $KeyLabel（直接回车保持不变，输入隐藏）"
    if ($null -eq $input) { $input = '' }
    $input = $input.Trim().Replace("`r",'').Replace("`n",'')
    if (-not $input) { return [pscustomobject]@{ KeptKey=$true; Value=$Existing } }
  } else {
    $input = Read-Secret "粘贴你的 $KeyLabel，然后按 Enter（输入隐藏）"
    if ($null -eq $input) { $input = '' }
    $input = $input.Trim().Replace("`r",'').Replace("`n",'')
    if (-not $input) { throw "$KeyLabel 不能为空" }
  }
  [pscustomobject]@{ KeptKey=$false; Value=$input }
}

function New-Model([string]$name,[string]$model,[string]$base,[string]$key) {
  [ordered]@{
    model_display_name = $name
    model             = $model
    base_url          = $base
    api_key           = $key
    provider          = 'openai'
    max_tokens        = 128000
  }
}

function Setup-Factory() {
  Write-Host
  Write-Host '=== 配置 Factory Droid CLI (~/.factory/config.json) ==='
  $userProfile = [Environment]::GetFolderPath('UserProfile')
  if (-not $userProfile) { $userProfile = $env:USERPROFILE }
  $dir = Join-Path $userProfile '.factory'
  $cfg = Join-Path $dir 'config.json'
  New-Item -ItemType Directory -Force -Path $dir | Out-Null

  $existingBase = ''
  $existingKey = ''
  $obj = $null
  if (Test-Path -LiteralPath $cfg) {
    try {
      $obj = Get-Content -Raw -LiteralPath $cfg | ConvertFrom-Json -ErrorAction Stop
      if ($obj.custom_models -and $obj.custom_models.Count -gt 0) {
        $existingBase = [string]$obj.custom_models[0].base_url
        $existingKey  = [string]$obj.custom_models[0].api_key
      }
    } catch {}
  }

  $sel = Select-Site 'Factory Droid CLI' '/v1' $existingBase
  $keyRes = Prompt-ApiKey 'OPENAI_API_KEY' $existingKey $sel.TokenUrl

  $baseToWrite = if ($sel.KeptBase) { $existingBase } else { $sel.BaseUrl }
  $keyToWrite  = if ($keyRes.KeptKey) { $existingKey } else { $keyRes.Value }

  if (Test-Path -LiteralPath $cfg) {
    Copy-Item -LiteralPath $cfg -Destination "$cfg.bak.$(Timestamp)" -Force
  }
  $be = Json-Escape $baseToWrite
  $ke = Json-Escape $keyToWrite
  $json = @"
{
  "custom_models": [
    {
      "model_display_name": "GPT-5.1 [Zeta]",
      "model": "gpt-5.1",
      "base_url": "$be",
      "api_key": "$ke",
      "provider": "openai",
      "max_tokens": 128000
    },
    {
      "model_display_name": "GPT-5.1 High [Zeta]",
      "model": "gpt-5.1-high",
      "base_url": "$be",
      "api_key": "$ke",
      "provider": "openai",
      "max_tokens": 128000
    },
    {
      "model_display_name": "GPT-5.1-Codex [Zeta]",
      "model": "gpt-5.1-codex",
      "base_url": "$be",
      "api_key": "$ke",
      "provider": "openai",
      "max_tokens": 128000
    },
    {
      "model_display_name": "GPT-5.1-Codex Mini [Zeta]",
      "model": "gpt-5-codex-mini",
      "base_url": "$be",
      "api_key": "$ke",
      "provider": "openai",
      "max_tokens": 128000
    },
    {
      "model_display_name": "GPT-5-mini [Zeta]",
      "model": "gpt-5-mini",
      "base_url": "$be",
      "api_key": "$ke",
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
    },
    {
      "model_display_name": "Gemini-3 Preview [Zeta]",
      "model": "gemini-3-pro-preview",
      "base_url": "$be",
      "api_key": "$ke",
      "provider": "generic-chat-completion-api",
      "max_tokens": 60000
    }
}
"@
  # Write JSON as UTF-8 without BOM to avoid parsers rejecting BOM-prefixed files
  $json = [Regex]::Replace($json, '"\:\s{2,}', '": ')
  # Write JSON as UTF-8 without BOM to avoid parsers rejecting BOM-prefixed files
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($cfg, $json, $utf8NoBom)

  Write-Host "✅ Factory Droid CLI 已配置: $cfg"
  if ($sel.KeptBase) { Write-Host "  base_url: 保持不变 ($existingBase)" } else { Write-Host "  base_url: $baseToWrite ($($sel.SiteName))" }
  if ($keyRes.KeptKey) { Write-Host "  API Key: 保持不变" } else { Write-Host "  API Key: 已更新" }
}

function Ensure-TrailingPath([string]$baseUrl, [string]$suffix) {
  if (-not $baseUrl) { return '' }
  $b = $baseUrl.Trim()
  if (-not $b) { return '' }
  $b = $b.TrimEnd('/')
  if (-not $suffix) { return $b }
  if ($b.EndsWith($suffix)) { return $b }
  return "$b$suffix"
}

function Strip-OpenCodeSuffix([string]$baseUrl) {
  if (-not $baseUrl) { return '' }
  $b = $baseUrl.Trim().TrimEnd('/')
  if ($b.EndsWith('/v1beta')) { return $b.Substring(0, $b.Length - '/v1beta'.Length) }
  if ($b.EndsWith('/v1')) { return $b.Substring(0, $b.Length - '/v1'.Length) }
  return $b
}

function Build-OpenCodeTemplate([string]$providerBase, [string]$siteLabel, [string]$baseV1, [string]$baseV1beta, [string]$apiKey) {
  $openaiId = "$providerBase-openai"
  $claudeId = "$providerBase-claude"
  $geminiId = "$providerBase-gemini"

  $keyEsc = Json-Escape $apiKey
  $v1Esc = Json-Escape $baseV1
  $v1bEsc = Json-Escape $baseV1beta

  @"
{
  "\$schema": "https://opencode.ai/config.json",
  "provider": {
    "$openaiId": {
      "npm": "@ai-sdk/openai",
      "name": "$siteLabel OpenAI",
      "options": {
        "baseURL": "$v1Esc",
        "apiKey": "$keyEsc"
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

    "$claudeId": {
      "npm": "@ai-sdk/anthropic",
      "name": "$siteLabel Claude",
      "options": {
        "baseURL": "$v1Esc",
        "apiKey": "$keyEsc"
      },
      "models": {
        "claude-haiku-4-5-20251001": { "name": "Claude-Haiku-4-5-20251001" },
        "claude-opus-4-5-20251101": { "name": "Claude-Opus-4-5-20251101" },
        "claude-opus-4-5-20251101-thinking": { "name": "Claude-Opus-4-5-20251101-thinking" },
        "claude-sonnet-4-5-20250929": { "name": "Claude-Sonnet-4-5-20250929" },
        "claude-sonnet-4-5-20250929-thinking": { "name": "Claude-Sonnet-4-5-20250929-thinking" }
      }
    },

    "$geminiId": {
      "npm": "@ai-sdk/google",
      "name": "$siteLabel Gemini",
      "options": {
        "baseURL": "$v1bEsc",
        "apiKey": "$keyEsc"
      },
      "models": {
        "gemini-3-pro-preview": { "name": "Gemini 3 Pro Preview" },
        "gemini-3-flash-preview": { "name": "Gemini 3 Flash Preview" }
      }
    }
  }
}
"@
}

function Read-OpenCodeProviderBase([string]$existing='') {
  Write-Host
  Write-Host '你选择了自定义 base_url。OpenCode 需要一个 provider 名称前缀用于生成 provider id：'
  Write-Host '  示例：my-zeta -> my-zeta-openai / my-zeta-claude / my-zeta-gemini'
  if ($existing) {
    Write-Host "提示：按 Enter 保持不变（当前: $existing）"
    $v = Read-Trim '请输入 provider 前缀（custom-name）' ''
    if (-not $v) { return $existing }
    return $v
  }
  $v = Read-Trim '请输入 provider 前缀（custom-name）' ''
  if (-not $v) { throw 'provider 前缀不能为空' }
  return $v
}

function Upsert-OpenCodeProviderKeys($obj, [string]$providerId, [string]$baseUrl, [string]$apiKey) {
  if (-not $obj.provider) { $obj | Add-Member -NotePropertyName provider -NotePropertyValue (@{}) }
  if (-not $obj.provider.$providerId) { $obj.provider.$providerId = @{} }
  if (-not $obj.provider.$providerId.options) { $obj.provider.$providerId.options = @{} }
  $obj.provider.$providerId.options.baseURL = $baseUrl
  $obj.provider.$providerId.options.apiKey = $apiKey
  return $obj
}

function Setup-OpenCode() {
  Write-Host
  Write-Host '=== 配置 OpenCode (opencode) (%USERPROFILE%\\.config\\opencode\\opencode.json) ==='

  $userProfile = [Environment]::GetFolderPath('UserProfile')
  if (-not $userProfile) { $userProfile = $env:USERPROFILE }

  $dir = Join-Path (Join-Path $userProfile '.config') 'opencode'
  $cfg = Join-Path $dir 'opencode.json'
  New-Item -ItemType Directory -Force -Path $dir | Out-Null

  $existingBaseV1 = ''
  $existingKey = ''
  $existingProviderBase = ''

  if (Test-Path -LiteralPath $cfg) {
    try {
      $obj = Get-Content -Raw -LiteralPath $cfg | ConvertFrom-Json -ErrorAction Stop
      $knownMain = 'zetatechs-api-openai'
      $knownEnt = 'zetatechs-api-enterprise-openai'
      $existingBaseV1 = [string]$obj.provider.$knownMain.options.baseURL
      $existingKey = [string]$obj.provider.$knownMain.options.apiKey
      if (-not $existingBaseV1) {
        $existingBaseV1 = [string]$obj.provider.$knownEnt.options.baseURL
        $existingKey = [string]$obj.provider.$knownEnt.options.apiKey
      }

      if ($existingBaseV1) {
        if ($existingBaseV1 -like 'https://api.zetatechs.com/*') { $existingProviderBase = 'zetatechs-api' }
        elseif ($existingBaseV1 -like 'https://ent.zetatechs.com/*') { $existingProviderBase = 'zetatechs-api-enterprise' }
      }
    } catch {}
  }

  $sel = Select-Site 'OpenCode (opencode)' '' (Strip-OpenCodeSuffix $existingBaseV1)
  $selectedSiteName = $sel.SiteName

  $selectedBaseRaw = if ($sel.KeptBase -and $existingBaseV1) { $existingBaseV1 } else { $sel.BaseUrl }
  $baseV1 = Ensure-TrailingPath $selectedBaseRaw '/v1'
  $baseV1beta = Ensure-TrailingPath $selectedBaseRaw '/v1beta'

  $providerBase = ''
  if ($selectedSiteName -eq '主站') { $providerBase = 'zetatechs-api' }
  elseif ($selectedSiteName -eq '企业站') { $providerBase = 'zetatechs-api-enterprise' }
  elseif ($selectedSiteName -eq '保持不变' -and $existingProviderBase) { $providerBase = $existingProviderBase }
  else { $providerBase = Read-OpenCodeProviderBase $existingProviderBase }

  $keyRes = Prompt-ApiKey 'OPENAI_API_KEY' $existingKey $sel.TokenUrl
  $keyToWrite = if ($keyRes.KeptKey) { $existingKey } else { $keyRes.Value }

  $siteLabel = "ZetaTechs $selectedSiteName"

  if (-not (Test-Path -LiteralPath $cfg)) {
    $json = Build-OpenCodeTemplate $providerBase $siteLabel $baseV1 $baseV1beta $keyToWrite
  } else {
    try {
      $obj2 = Get-Content -Raw -LiteralPath $cfg | ConvertFrom-Json -ErrorAction Stop
      $openaiId = "$providerBase-openai"
      $claudeId = "$providerBase-claude"
      $geminiId = "$providerBase-gemini"
      $obj2 = Upsert-OpenCodeProviderKeys $obj2 $openaiId $baseV1 $keyToWrite
      $obj2 = Upsert-OpenCodeProviderKeys $obj2 $claudeId $baseV1 $keyToWrite
      $obj2 = Upsert-OpenCodeProviderKeys $obj2 $geminiId $baseV1beta $keyToWrite
      Copy-Item -LiteralPath $cfg -Destination "$cfg.bak.$(Timestamp)" -Force
      $json = $obj2 | ConvertTo-Json -Depth 50
    } catch {
      Copy-Item -LiteralPath $cfg -Destination "$cfg.bak.$(Timestamp)" -Force
      $json = Build-OpenCodeTemplate $providerBase $siteLabel $baseV1 $baseV1beta $keyToWrite
    }
  }

  # Write JSON as UTF-8 without BOM
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($cfg, $json, $utf8NoBom)

  Write-Host "✅ OpenCode (opencode) 已配置: $cfg"
  Write-Host "  provider 前缀: $providerBase"
  Write-Host "  baseURL (OpenAI/Claude): $baseV1"
  Write-Host "  baseURL (Gemini): $baseV1beta"
  if ($keyRes.KeptKey) { Write-Host '  API Key: 保持不变' } else { Write-Host '  API Key: 已更新' }
}

function Setup-Anthropic() {
  Write-Host
  Write-Host '=== 配置 Anthropic Claude Code CLI (Windows 用户级环境变量) ==='
  $existingBase = [Environment]::GetEnvironmentVariable('ANTHROPIC_BASE_URL','User')
  if (-not $existingBase) { $existingBase = [Environment]::GetEnvironmentVariable('ANTHROPIC_BASE_URL','Process') }
  $existingKey  = [Environment]::GetEnvironmentVariable('ANTHROPIC_AUTH_TOKEN','User')
  if (-not $existingKey)  { $existingKey  = [Environment]::GetEnvironmentVariable('ANTHROPIC_AUTH_TOKEN','Process') }

  $sel = Select-Site 'Anthropic Claude Code CLI' '' $existingBase
  $keyRes = Prompt-ApiKey 'ANTHROPIC_AUTH_TOKEN' $existingKey $sel.TokenUrl

  if (-not $sel.KeptBase) {
    [Environment]::SetEnvironmentVariable('ANTHROPIC_BASE_URL', $sel.BaseUrl, 'User')
    $env:ANTHROPIC_BASE_URL = $sel.BaseUrl
  }
  if (-not $keyRes.KeptKey) {
    [Environment]::SetEnvironmentVariable('ANTHROPIC_AUTH_TOKEN', $keyRes.Value, 'User')
    $env:ANTHROPIC_AUTH_TOKEN = $keyRes.Value
  }

  Write-Host '✅ Anthropic Claude Code CLI 配置完成。'
  if ($sel.KeptBase) { Write-Host "  ANTHROPIC_BASE_URL: 保持不变 ($existingBase)" } else { Write-Host "  ANTHROPIC_BASE_URL: $($sel.BaseUrl) ($($sel.SiteName))" }
  if ($keyRes.KeptKey) { Write-Host "  ANTHROPIC_AUTH_TOKEN: 保持不变" } else { Write-Host '  ANTHROPIC_AUTH_TOKEN: 已更新' }
  Write-Host '提示：新开一个 PowerShell 窗口或在当前会话已即时生效。'
}


Write-Host '=== Zetatechs Coding CLI 配置向导 (Windows/PowerShell) ==='
Write-Host
Write-Host '请选择要配置的应用：'
Write-Host '  1) Factory Droid CLI'
Write-Host '  2) Anthropic Claude Code CLI'
Write-Host '  3) OpenCode (opencode)'

$choice = Read-Trim '输入选项 [1/2/3] (默认 1)' '1'
switch ($choice) {
  '1' { Setup-Factory }
  '2' { Setup-Anthropic }
  '3' { Setup-OpenCode }
  Default { throw "无效选项：$choice" }
}


Write-Host
Write-Host '完成。再次运行本脚本时：'
Write-Host '- 如不选择站点或不输入 API Key，将保持现有配置不变（不会清空）。'
