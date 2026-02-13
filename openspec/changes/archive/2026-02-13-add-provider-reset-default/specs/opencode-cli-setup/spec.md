## MODIFIED Requirements

### Requirement: Add vs Update Provider Group
The setup flow SHALL ask whether the user wants to add a new provider group, update an existing provider group, or restore provider settings to software defaults.

#### Scenario: Add a new group
- **WHEN** the user chooses to add a new provider group
- **THEN** the flow prompts for a provider base prefix
- **AND THEN** the system creates or upserts the three provider IDs for that base prefix

#### Scenario: Update an existing group
- **WHEN** the user chooses to update an existing provider group
- **THEN** the flow prompts the user to select an existing provider base prefix
- **AND THEN** only that provider group's base URL values are updated

#### Scenario: Restore defaults action selected
- **WHEN** the user chooses the restore-default action in provider setup
- **THEN** the flow prompts for explicit destructive confirmation
- **AND THEN** the flow runs restore-default behavior instead of add/update provider-group mutation

## ADDED Requirements

### Requirement: Restore OpenCode Provider Defaults
The system SHALL allow users to restore OpenCode provider settings to software defaults by removing the OpenCode local configuration file after explicit confirmation.

#### Scenario: Confirmed restore deletes config file
- **WHEN** `opencode.json` exists
- **AND WHEN** the user selects restore-default and confirms the destructive action
- **THEN** the script creates a timestamped backup of the existing file
- **AND THEN** the script deletes `opencode.json`
- **AND THEN** the script reports that OpenCode provider configuration has been reset to software defaults

#### Scenario: Restore canceled
- **WHEN** the user selects restore-default
- **AND WHEN** the user does not provide the required confirmation
- **THEN** the script leaves `opencode.json` unchanged

#### Scenario: Config already at defaults
- **WHEN** the user selects restore-default
- **AND WHEN** `opencode.json` does not exist
- **THEN** the script reports that provider settings are already at software defaults and exits without error
