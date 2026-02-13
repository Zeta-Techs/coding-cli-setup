## MODIFIED Requirements

### Requirement: File-Based Reset Behavior
For file-based targets, the system SHALL restore defaults by deleting managed config files after explicit confirmation and SHALL create timestamped backups for any managed file that exists.

#### Scenario: OpenCode reset deletes config file
- **WHEN** the user confirms restore-default for OpenCode
- **THEN** the script backs up `opencode.json` if it exists
- **AND THEN** the script deletes `opencode.json`

#### Scenario: Factory reset deletes config file
- **WHEN** the user confirms restore-default for Factory Droid CLI
- **THEN** the script backs up the target `config.json` if it exists
- **AND THEN** the script deletes that `config.json`

### Requirement: Anthropic Environment Reset Behavior
For Anthropic Claude Code CLI, the system SHALL restore defaults by removing managed environment variable settings for `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN` from persistent storage and from the current process where supported.

#### Scenario: Bash Anthropic reset removes rc exports
- **WHEN** the user confirms restore-default for Anthropic in the Bash script
- **THEN** the script removes managed export lines for `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN` from `~/.bashrc` and `~/.zshrc`

#### Scenario: Bash Anthropic reset clears process env
- **WHEN** the user confirms restore-default for Anthropic in the Bash script
- **THEN** the script unsets process-level `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN` for the running shell process

#### Scenario: PowerShell Anthropic reset removes user env vars
- **WHEN** the user confirms restore-default for Anthropic in the PowerShell script
- **THEN** the script removes user-level `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN` values

#### Scenario: PowerShell Anthropic reset clears process env
- **WHEN** the user confirms restore-default for Anthropic in the PowerShell script
- **THEN** the script removes process-level `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN` values

## ADDED Requirements

### Requirement: Codex Environment Reset Behavior
For OpenAI Codex CLI in the Bash script, the system SHALL restore defaults by clearing Codex-related environment variables and SHALL NOT delete `~/.codex/config.toml` or `~/.codex/auth.json` during restore-default.

#### Scenario: Codex reset clears env vars only
- **WHEN** the user confirms restore-default for OpenAI Codex CLI in the Bash script
- **THEN** the script removes `OPENAI_API_KEY` and `OPENAI_BASE_URL` from managed shell rc exports when present
- **AND THEN** the script unsets process-level `OPENAI_API_KEY` and `OPENAI_BASE_URL`
- **AND THEN** the script does not delete `~/.codex/config.toml` or `~/.codex/auth.json`

#### Scenario: Codex reset with no env vars set
- **WHEN** the user confirms restore-default for OpenAI Codex CLI in the Bash script
- **AND WHEN** no managed `OPENAI_API_KEY` or `OPENAI_BASE_URL` values are present
- **THEN** the script exits without error and reports that Codex is already at defaults
