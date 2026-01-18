## ADDED Requirements

### Requirement: Repository README Accuracy
The repository SHALL provide a README that accurately describes the supported setup targets and the expected configuration file locations.

#### Scenario: OpenCode is documented
- **WHEN** OpenCode (opencode) setup is supported by the scripts
- **THEN** the README lists OpenCode (opencode) as a supported target
- **AND THEN** the README documents the OpenCode config file path for macOS/Linux/WSL (`~/.config/opencode/opencode.json`) and Windows (`%USERPROFILE%\.config\opencode\opencode.json`)

#### Scenario: Menu options match scripts
- **WHEN** the README describes menu selection options
- **THEN** the described option numbers match the current scripts

#### Scenario: Language style preserved
- **WHEN** new README content is added for OpenCode
- **THEN** the README remains Chinese-first
- **AND THEN** it includes brief English clarifications for OpenCode-related additions
