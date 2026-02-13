## 1. Implementation
- [x] 1.1 Add a shared restore-default action pattern (action selection + explicit confirmation text) for setup flows in Bash
- [x] 1.2 Implement Bash OpenCode reset: backup and delete `~/.config/opencode/opencode.json`
- [x] 1.3 Implement Bash Codex reset: backup and delete `~/.codex/config.toml` and `~/.codex/auth.json`
- [x] 1.4 Implement Bash Factory Droid reset: backup and delete `~/.factory/config.json`
- [x] 1.5 Implement Bash Anthropic reset: remove managed `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN` export lines from `~/.bashrc` and `~/.zshrc`
- [x] 1.6 Add a shared restore-default action pattern (action selection + explicit confirmation text) for setup flows in PowerShell
- [x] 1.7 Implement PowerShell OpenCode reset: backup and delete `%USERPROFILE%\.config\opencode\opencode.json`
- [x] 1.8 Implement PowerShell Factory Droid reset: backup and delete `%USERPROFILE%\.factory\config.json`
- [x] 1.9 Implement PowerShell Anthropic reset: remove user-level `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN`
- [x] 1.10 Ensure completion messaging consistently reports when a target has been restored to software defaults

## 2. Validation / QA
- [x] 2.1 Smoke test (Bash OpenCode/Codex/Factory): confirm reset creates backups and removes target config files
- [x] 2.2 Smoke test (PowerShell OpenCode/Factory): confirm reset creates backups and removes target config files
- [x] 2.3 Smoke test (Bash + PowerShell Anthropic): confirm reset removes managed environment variable settings
- [x] 2.4 Smoke test (all targets): cancel restore confirmation and verify no settings are removed
- [x] 2.5 Smoke test (all targets): run restore when settings do not exist and verify no-error "already default" behavior

## 3. Spec / Proposal Hygiene
- [x] 3.1 Run `openspec validate add-provider-reset-default --strict` and resolve all issues
- [x] 3.2 Request approval before starting implementation
