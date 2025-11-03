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

  $models = @(
    New-Model 'GPT-5 [Zeta]' 'gpt-5' $baseToWrite $keyToWrite
    New-Model 'GPT-5 High [Zeta]' 'gpt-5-high' $baseToWrite $keyToWrite
    New-Model 'GPT-5-Codex [Zeta]' 'gpt-5-codex' $baseToWrite $keyToWrite
    New-Model 'GPT-5-Codex High [Zeta]' 'gpt-5-codex-high' $baseToWrite $keyToWrite
    New-Model 'GPT-5-mini [Zeta]' 'gpt-5-mini' $baseToWrite $keyToWrite
    New-Model 'GPT-5-mini High [Zeta]' 'gpt-5-mini-high' $baseToWrite $keyToWrite
  )

  $outObj = $null
  if ($obj) {
    $obj.custom_models = $models
    $outObj = $obj
  } else {
    $outObj = [ordered]@{ custom_models = $models }
  }

  if (Test-Path -LiteralPath $cfg) {
    Copy-Item -LiteralPath $cfg -Destination "$cfg.bak.$(Timestamp)" -Force
  }
  $json = $outObj | ConvertTo-Json -Depth 6
  # Write JSON as UTF-8 without BOM to avoid parsers rejecting BOM-prefixed files
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($cfg, $json, $utf8NoBom)

  Write-Host "✅ Factory Droid CLI 已配置: $cfg"
  if ($sel.KeptBase) { Write-Host "  base_url: 保持不变 ($existingBase)" } else { Write-Host "  base_url: $baseToWrite ($($sel.SiteName))" }
  if ($keyRes.KeptKey) { Write-Host "  API Key: 保持不变" } else { Write-Host "  API Key: 已更新" }
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

$choice = Read-Trim '输入选项 [1/2] (默认 1)' '1'
switch ($choice) {
  '1' { Setup-Factory }
  '2' { Setup-Anthropic }
  Default { throw "无效选项：$choice" }
}

Write-Host
Write-Host '完成。再次运行本脚本时：'
Write-Host '- 如不选择站点或不输入 API Key，将保持现有配置不变（不会清空）。'
