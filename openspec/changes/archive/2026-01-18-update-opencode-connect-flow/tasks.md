## 1. Implementation
- [x] 1.1 Update tool selection menus to list OpenCode first (Bash + PowerShell); place Factory fourth in 4-item lists
- [x] 1.2 Update README tool lists and menu instructions to match the new ordering and naming (OpenCode)
- [x] 1.3 Update Bash OpenCode flow to stop prompting for API keys; print `/connect` instructions instead
- [x] 1.4 Implement Bash OpenCode provider-group management: add vs update, preserve other groups, list providers, optional delete
- [x] 1.5 Update PowerShell OpenCode flow to stop prompting for API keys; print `/connect` instructions instead
- [x] 1.6 Implement PowerShell OpenCode provider-group management: add vs update, preserve other groups, list providers, optional delete
- [x] 1.7 Fix PowerShell OpenCode base URL derivation bug for `/v1` vs `/v1beta` when keeping existing base
- [x] 1.8 Harden Bash OpenCode behavior when `jq` is missing or existing JSON is invalid (avoid unintended full overwrite)

## 2. Validation / QA
- [x] 2.1 Smoke test (macOS/Linux/WSL): create new `~/.config/opencode/opencode.json`; re-run with add/update; verify other providers preserved
- [x] 2.2 Smoke test (macOS/Linux/WSL): run without `jq` present; confirm the script aborts or requires explicit overwrite confirmation
- [x] 2.3 Smoke test (Windows/PowerShell): create new `%USERPROFILE%\\.config\\opencode\\opencode.json`; re-run with add/update; verify other providers preserved
- [x] 2.4 Smoke test (Windows/PowerShell): keep existing base URL and verify Gemini base is `/v1beta` (no `/v1/v1beta`)
- [x] 2.5 Run `shellcheck` on `coding-cli-setup.sh` if available (non-blocking) and fix issues introduced by this change

## 3. Spec / Proposal Hygiene
- [x] 3.1 Run `openspec validate update-opencode-connect-flow --strict` and fix any issues
- [x] 3.2 Request approval before starting implementation
