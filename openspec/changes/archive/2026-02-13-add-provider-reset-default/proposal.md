# Change: Add restore-default option for all supported CLI setups

## Why
Users need a consistent way to revert provider configuration back to each tool's software defaults across all supported setup targets, not only OpenCode.

Today, setup flows focus on writing or updating values. Resetting to defaults requires manual deletion of config files or environment variables, which is error-prone and inconsistent between tools and platforms.

## What Changes
- Add a `恢复默认设置` option to each supported setup target's provider configuration flow.
- Scope the option to all currently supported tools in this repository:
  - OpenCode
  - OpenAI Codex CLI (Bash script only)
  - Anthropic Claude Code CLI
  - Factory Droid CLI
- Implement explicit destructive confirmation before any reset action.
- Reset behavior by storage type:
  - File-based tools: create timestamped backup, then delete managed config file(s).
  - Environment-variable-based tool (Anthropic): remove managed environment variable settings to restore defaults.
- Keep existing add/update flows unchanged when reset is not selected.

## Impact
- Affected specs:
  - `opencode-cli-setup`
  - New capability proposed: `cli-default-reset`
- Affected code:
  - `coding-cli-setup.sh`
  - `coding-cli-setup.ps1`
- Affected user files/settings:
  - OpenCode:
    - macOS/Linux/WSL: `~/.config/opencode/opencode.json`
    - Windows: `%USERPROFILE%\.config\opencode\opencode.json`
  - OpenAI Codex CLI (Bash): `~/.codex/config.toml`, `~/.codex/auth.json`
  - Factory Droid CLI:
    - macOS/Linux/WSL: `~/.factory/config.json`
    - Windows: `%USERPROFILE%\.factory\config.json`
  - Anthropic Claude Code CLI:
    - macOS/Linux/WSL: `~/.bashrc` / `~/.zshrc` entries for `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN`
    - Windows: user-level `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN`
