## 1. Implementation
- [ ] 1.1 Add OpenCode (opencode) as an app option in `coding-cli-setup.sh`
- [ ] 1.2 Implement OpenCode config read/update logic in `coding-cli-setup.sh` (create full template when missing; JSON merge; jq optional)
- [ ] 1.3 Add OpenCode (opencode) as an app option in `coding-cli-setup.ps1`
- [ ] 1.4 Implement OpenCode config read/update logic in `coding-cli-setup.ps1` (create full template when missing; JSON merge; UTF-8 no BOM)
- [ ] 1.5 Manual smoke test on macOS/Linux/WSL: create/update `~/.config/opencode/opencode.json`, re-run keeps values
- [ ] 1.6 Manual smoke test on Windows: create/update `%USERPROFILE%\.config\opencode\opencode.json`, re-run keeps values

## 2. Spec / Validation
- [ ] 2.1 Run `openspec validate add-opencode-cli-support --strict` and fix any issues
- [ ] 2.2 Request approval before starting implementation
