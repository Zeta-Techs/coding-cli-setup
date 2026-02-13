## 1. Implementation
- [x] 1.1 Update Bash Codex restore-default flow to clear `OPENAI_API_KEY` and `OPENAI_BASE_URL` instead of deleting `~/.codex` files
- [x] 1.2 Update Bash Claude restore-default flow to clear current-session `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN` in addition to rc cleanup
- [x] 1.3 Update PowerShell Claude restore-default flow to ensure both user-level and process-level `ANTHROPIC_*` values are cleared
- [x] 1.4 Ensure restore-default completion messages clearly reflect env-var reset behavior for Codex and Claude

## 2. Validation / QA
- [x] 2.1 Smoke test (Bash Codex): restore-default clears `OPENAI_API_KEY`/`OPENAI_BASE_URL` and does not delete `~/.codex/config.toml` or `~/.codex/auth.json`
- [x] 2.2 Smoke test (Bash Claude): restore-default removes rc exports and clears current-session `ANTHROPIC_*`
- [x] 2.3 Smoke test (PowerShell Claude): restore-default removes user-level and process-level `ANTHROPIC_*`
- [x] 2.4 Smoke test (Bash + PowerShell): cancel restore confirmation keeps all env vars unchanged
- [x] 2.5 Smoke test (Bash + PowerShell): restore-default on already-default env vars exits without error

## 3. Spec / Proposal Hygiene
- [x] 3.1 Run `openspec validate update-reset-env-for-codex-claude --strict` and resolve all issues
- [x] 3.2 Request approval before starting implementation
