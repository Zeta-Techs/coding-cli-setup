## ADDED Requirements

### Requirement: Restore-Default Option Availability
The system SHALL provide a `恢复默认设置` action during provider setup for each target supported by the script currently being run.

#### Scenario: Bash targets include restore-default
- **WHEN** the user runs `coding-cli-setup.sh` and enters any supported target flow (OpenCode, OpenAI Codex CLI, Anthropic Claude Code CLI, or Factory Droid CLI)
- **THEN** that target flow includes a `恢复默认设置` action

#### Scenario: PowerShell targets include restore-default
- **WHEN** the user runs `coding-cli-setup.ps1` and enters any supported target flow (OpenCode, Anthropic Claude Code CLI, or Factory Droid CLI)
- **THEN** that target flow includes a `恢复默认设置` action

### Requirement: File-Based Reset Behavior
For file-based targets, the system SHALL restore defaults by deleting managed config files after explicit confirmation and SHALL create timestamped backups for any managed file that exists.

#### Scenario: OpenCode reset deletes config file
- **WHEN** the user confirms restore-default for OpenCode
- **THEN** the script backs up `opencode.json` if it exists
- **AND THEN** the script deletes `opencode.json`

#### Scenario: Codex reset deletes both managed files
- **WHEN** the user confirms restore-default for OpenAI Codex CLI in the Bash script
- **THEN** the script backs up `~/.codex/config.toml` and `~/.codex/auth.json` if they exist
- **AND THEN** the script deletes `~/.codex/config.toml` and `~/.codex/auth.json`

#### Scenario: Factory reset deletes config file
- **WHEN** the user confirms restore-default for Factory Droid CLI
- **THEN** the script backs up the target `config.json` if it exists
- **AND THEN** the script deletes that `config.json`

### Requirement: Anthropic Environment Reset Behavior
For Anthropic Claude Code CLI, the system SHALL restore defaults by removing managed environment variable settings for `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN`.

#### Scenario: Bash Anthropic reset removes rc exports
- **WHEN** the user confirms restore-default for Anthropic in the Bash script
- **THEN** the script removes managed export lines for `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN` from `~/.bashrc` and `~/.zshrc`

#### Scenario: PowerShell Anthropic reset removes user env vars
- **WHEN** the user confirms restore-default for Anthropic in the PowerShell script
- **THEN** the script removes user-level `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN` values

### Requirement: Reset Safety and Idempotency
The system SHALL require explicit destructive confirmation before reset, SHALL leave settings unchanged when confirmation is not provided, and SHALL succeed when targets are already at defaults.

#### Scenario: Reset confirmation canceled
- **WHEN** the user selects restore-default but does not provide the required confirmation input
- **THEN** the script does not delete any managed config file or environment variable setting

#### Scenario: Already-default target
- **WHEN** the user confirms restore-default for a target that has no managed config file or environment variable setting present
- **THEN** the script exits without error
- **AND THEN** the script reports that the target is already at software defaults
