# Project Context

## Purpose
This repo provides a small, interactive setup utility for configuring multiple "coding CLI" tools to use ZetaTechs-hosted API endpoints.

Primary goals:
- Make first-time setup fast (single command, guided prompts)
- Keep secrets out of the repo (write only to user home directories)
- Be repeatable and safe to re-run (press Enter to keep existing values)
- Work across common environments: macOS/Linux/WSL via Bash, Windows via PowerShell

## Tech Stack
- Bash (`coding-cli-setup.sh`) for macOS/Linux/WSL
- PowerShell (`coding-cli-setup.ps1`) for Windows
- Optional local tooling:
  - `jq` (if installed) to validate/merge JSON in Bash
- Config formats written by the scripts:
  - JSON (`~/.factory/config.json`, `~/.codex/auth.json`)
  - TOML (`~/.codex/config.toml`)
  - Shell RC export lines (`~/.bashrc`, `~/.zshrc`)
- Documentation:
  - README is primarily in Chinese; user-facing prompts/messages are in Chinese

## Repository Layout
- `coding-cli-setup.sh`: Interactive setup for macOS/Linux/WSL (safe for `curl | bash` style usage via `/dev/tty` reads)
- `coding-cli-setup.ps1`: Interactive setup for Windows PowerShell (`iex (irm ...)`)
- `openspec/`: OpenSpec project context, specs, and change proposals

## Project Conventions

### Code Style
- Prefer small, self-contained scripts (minimal dependencies; graceful fallback when tools like `jq` are missing)
- Bash:
  - Use `set -Eeuo pipefail` and `umask 077` for safety
  - Quote variables; avoid unsafe word-splitting
  - Prefer helper functions for repeated behaviors (prompting, site selection, file writes)
  - Be explicit about file permissions for credential material (`chmod 600`)
  - Be safe for `curl | bash` usage:
    - Read interactive input from `/dev/tty` (not stdin)
- PowerShell:
  - Use `Set-StrictMode -Version Latest` and `$ErrorActionPreference = 'Stop'`
  - Prefer helper functions returning objects (`[pscustomobject]`) for multi-value results
  - Write files as UTF-8 without BOM when possible to avoid JSON parsers rejecting BOM-prefixed files
- User interaction:
  - Default options are provided; pressing Enter typically keeps existing config where applicable
  - Secret input should be hidden where possible
  - Avoid echoing secrets back to the terminal

### Architecture Patterns
- Single entrypoint scripts with small helper functions (e.g., selecting a site, prompting for tokens, writing config)
- Idempotent configuration writes:
  - Re-running should not clear settings unless the user provides new values
  - Backup pre-existing config files before overwriting (e.g., `.bak.<timestamp>`)
- Local-only credential handling:
  - Never print full tokens to stdout
  - Never write secrets into the repo; only into user home directories / user environment variables

### Testing Strategy
- No formal automated test suite in this repo currently.
- Primary verification is manual smoke testing:
  - Run scripts on the target OS/shell and confirm expected files/values are created
  - Re-run and confirm "keep existing" behavior for both base URL and credentials
  - Validate JSON where applicable (e.g., `jq . ~/.factory/config.json` if `jq` is installed)
  - On Windows, confirm:
    - `%USERPROFILE%\.factory\config.json` is valid JSON and has no BOM-related parse issues
    - User-level env vars `ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN` are set

### Git Workflow
- Work happens on small, reviewable commits on `main` (no special branching rules documented here).
- Commit messages in this repo are short and imperative; keep them descriptive and scoped to the change.
- Do not commit secrets or machine-local config.

## Domain Context
Configured tools (as of current scripts):
- Factory Droid CLI
  - Writes config to `~/.factory/config.json` (also on Windows: `%USERPROFILE%\.factory\config.json`)
  - Writes a `custom_models` array with ZetaTechs-branded model entries; models are routed via a selected `base_url`
  - Prefers `jq` for strict JSON generation/merge; falls back to string-based JSON generation if missing
- OpenAI Codex CLI (macOS/Linux/WSL only)
  - Writes `~/.codex/config.toml` and `~/.codex/auth.json`
  - Uses a model provider named `zetatechs` with a selected `base_url` and `wire_api = "responses"`
- Anthropic Claude Code CLI
  - On macOS/Linux/WSL: writes `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN` exports into `~/.bashrc` and `~/.zshrc`
  - On Windows: sets user-level environment variables for the same keys

Site selection conventions:
- The scripts offer preset ZetaTechs hosts (main/enterprise/codex) plus a custom base URL option.
- The Bash script uses `base_suffix` to choose whether to append `/v1` (Factory/Codex use `/v1`; Anthropic defaults to no suffix).
- A convenience "token page" URL is derived from the selected host (`https://<host>/console/token`) and displayed to help users retrieve credentials.
- "Press Enter to keep existing" is treated as the primary idempotency mechanism for both base URL and API key.

## Important Constraints
- Must remain safe to execute via "curl | bash" patterns:
  - Avoid interactive reads from stdin; use `/dev/tty` where needed
  - Avoid requiring external dependencies beyond the shell itself
- Cross-platform behavior matters:
  - Bash script targets macOS/Linux/WSL
  - PowerShell script targets Windows PowerShell
- Security hygiene is a top priority:
  - Use restrictive file permissions for secrets
  - Avoid logging or committing secrets

## External Dependencies
- ZetaTechs API endpoints (user-selectable base URLs)
- Third-party CLIs configured by these scripts:
  - Factory Droid CLI
  - OpenAI Codex CLI
  - Anthropic Claude Code CLI
