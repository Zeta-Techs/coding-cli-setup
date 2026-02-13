# Change: Update restore-default to clear environment variables for Codex and Claude

## Why
The current restore-default behavior does not match expected usage for Codex and Claude Code. Users expect restore-default to clear environment-variable-based settings, but the script currently cannot reliably do this workflow.

For Codex in particular, users requested that restore-default should clear environment variables only, not delete `~/.codex` config files.

## What Changes
- Update restore-default behavior for OpenAI Codex CLI:
  - Stop deleting `~/.codex/config.toml` and `~/.codex/auth.json` during restore-default.
  - Clear Codex-related environment variables instead.
- Harden restore-default behavior for Anthropic Claude Code CLI so env var cleanup is effective in practice:
  - Keep removing persisted settings (rc exports on Bash, user-level env vars on PowerShell).
  - Also clear current-session environment variables where applicable.
- Keep OpenCode and Factory reset behavior unchanged (file backup + deletion).

## Impact
- Affected specs:
  - `cli-default-reset`
- Affected code:
  - `coding-cli-setup.sh`
  - `coding-cli-setup.ps1`
- Affected user settings:
  - Codex env vars (for restore-default): `OPENAI_API_KEY`, `OPENAI_BASE_URL`
  - Claude env vars: `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`
