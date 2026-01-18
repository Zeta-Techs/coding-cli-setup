# Change: Add OpenCode (opencode) CLI configuration support

## Why
Users want the same guided ZetaTechs endpoint + credential setup experience for OpenCode that already exists for Factory Droid, Codex, and Claude Code.

## What Changes
- Add OpenCode (opencode) as a configurable target in the setup scripts.
- Write/update OpenCode XDG config (`opencode.json`) to include ZetaTechs provider definitions.
- Provider ID conventions:
  - Preset main site: `zetatechs-api-<suffix>`
  - Preset enterprise site: `zetatechs-api-enterprise-<suffix>`
  - Custom site: `<custom-name>-<suffix>` (user is prompted for `<custom-name>`)
  - `<suffix>` is one of: `openai`, `claude`, `gemini`
- If the OpenCode config file does not exist, create it using a full provider template (based on the standard `opencode.json` example) and only vary `options.baseURL` and `options.apiKey`.
- Keep the setup idempotent: re-running with Enter keeps existing values.
- Preserve security hygiene: never print full tokens; write config with restrictive permissions.

## Impact
- Affected specs:
  - New capability proposed: `opencode-cli-setup`
- Affected code:
  - `coding-cli-setup.sh`
  - `coding-cli-setup.ps1`
- Affected user files:
  - macOS/Linux/WSL: `~/.config/opencode/opencode.json`
  - Windows: `%USERPROFILE%\\.config\\opencode\\opencode.json`
