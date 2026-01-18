# Change: Update OpenCode Setup to Use /connect and Support Multiple Providers

## Why
OpenCode setup currently behaves like the other CLIs: it prompts for an API key and writes `options.apiKey` into `opencode.json`. This is not the preferred OpenCode workflow (users should use OpenCode's `/connect` to store provider API keys), and it makes the setup script handle secrets it does not need to handle.

In addition, OpenCode is currently listed last in some menus/docs and the naming is inconsistent ("OpenCode (opencode)", "Open Code"). The user request is to standardize on the product name "OpenCode" and place it first in tool lists.

Finally, the current Bash fallback behavior for OpenCode (when `jq` is missing or the existing JSON is invalid) can overwrite the entire `opencode.json`, which is risky once users start managing multiple providers.

## What Changes
- Standardize display naming:
  - Replace user-facing "OpenCode (opencode)" / "Open Code" with "OpenCode".
  - Keep filesystem paths and schema URLs unchanged (they still contain `opencode`).
- Reorder tool lists and menus:
  - Put OpenCode first in tool selection menus and in README tool lists.
  - Put Factory Droid CLI fourth in 4-item lists (Bash).
  - Windows/PowerShell keeps a 3-item menu (per user decision); Factory becomes third there.
- Update OpenCode setup flow:
  - Do not prompt for an API key.
  - Do not write or overwrite provider `options.apiKey` values.
  - Print a clear next step telling users to run `/connect` inside OpenCode and choose the configured provider(s) to enter API keys.
- Add OpenCode provider management:
  - Support multiple provider "groups" (multiple provider base prefixes), each group containing the three provider IDs: `-openai`, `-claude`, `-gemini`.
  - Prompt whether this run is adding a new group or updating an existing group.
  - Preserve other providers/groups and existing `models` blocks.
  - After setup, list all providers found in the config; optionally offer deletion of a selected provider group (backup first).
- Fix unsafe/incorrect behaviors identified during repo review:
  - Bash: avoid silent full-file overwrite when `jq` is missing / JSON invalid; require explicit confirmation or abort (with a backup when overwriting).
  - PowerShell: fix base URL derivation so that keeping an existing `/v1` base does not produce `/v1/v1beta` for Gemini.

## Impact
- Affected specs:
  - `docs` (README wording + menu ordering/numbers)
  - New capability proposed: `opencode-cli-setup` (OpenCode-specific setup behavior)
- Affected code:
  - `coding-cli-setup.sh`
  - `coding-cli-setup.ps1`
  - `README.md`
- Affected user files:
  - macOS/Linux/WSL: `~/.config/opencode/opencode.json`
  - Windows: `%USERPROFILE%\\.config\\opencode\\opencode.json`
