## ADDED Requirements

### Requirement: OpenCode Setup Target
The system SHALL provide an interactive setup path to configure OpenCode to use a user-selected ZetaTechs API base URL.

#### Scenario: User selects OpenCode setup
- **WHEN** the user selects OpenCode from the setup menu
- **THEN** the setup flow prompts for site selection and OpenCode provider management options

### Requirement: OpenCode Config File Location
The system SHALL write OpenCode configuration to an XDG config location.

#### Scenario: macOS/Linux/WSL path
- **WHEN** the user runs the Bash setup script
- **THEN** the script writes to `~/.config/opencode/opencode.json`

#### Scenario: Windows path
- **WHEN** the user runs the PowerShell setup script
- **THEN** the script writes to `%USERPROFILE%\\.config\\opencode\\opencode.json`

### Requirement: Provider Groups
The system SHALL support configuring multiple OpenCode provider groups within `opencode.json`.

A provider group is defined by a shared provider base prefix and SHALL include three provider IDs:
- `<base>-openai`
- `<base>-claude`
- `<base>-gemini`

#### Scenario: Multiple groups preserved
- **WHEN** `opencode.json` already contains multiple provider groups
- **THEN** configuring one group does not remove or rewrite other groups

### Requirement: Add vs Update Provider Group
The setup flow SHALL ask whether the user wants to add a new provider group or update an existing provider group.

#### Scenario: Add a new group
- **WHEN** the user chooses to add a new provider group
- **THEN** the flow prompts for a provider base prefix
- **AND THEN** the system creates or upserts the three provider IDs for that base prefix

#### Scenario: Update an existing group
- **WHEN** the user chooses to update an existing provider group
- **THEN** the flow prompts the user to select an existing provider base prefix
- **AND THEN** only that provider group's base URL values are updated

### Requirement: Provider Base URLs
The system SHALL set provider base URLs according to the OpenCode provider type.

#### Scenario: OpenAI and Claude use /v1
- **WHEN** the user selects a site preset or provides a custom base URL
- **THEN** the OpenAI and Claude providers use a base URL ending in `/v1`

#### Scenario: Gemini uses /v1beta
- **WHEN** the user selects a site preset or provides a custom base URL
- **THEN** the Gemini provider uses a base URL ending in `/v1beta`

### Requirement: No API Key Prompts
The system SHALL NOT prompt for API keys during OpenCode setup.

#### Scenario: /connect guidance shown
- **WHEN** OpenCode setup completes
- **THEN** the script prints guidance telling the user to run `/connect` in OpenCode and select the configured provider to enter an API key

### Requirement: Preserve Existing Secrets
The system SHALL NOT delete or overwrite existing OpenCode provider API keys during setup.

#### Scenario: Existing apiKey preserved
- **WHEN** `opencode.json` contains `provider.<id>.options.apiKey`
- **AND WHEN** the user updates provider base URLs
- **THEN** the existing `apiKey` value remains unchanged

### Requirement: Provider Listing and Optional Deletion
The system SHALL list providers found in the OpenCode config after setup and SHALL offer an optional deletion operation.

#### Scenario: Providers are listed
- **WHEN** OpenCode setup completes
- **THEN** the script prints the list of provider IDs currently present in `opencode.json`

#### Scenario: Delete a provider group
- **WHEN** the user chooses to delete a provider group
- **THEN** the script deletes the three provider IDs for the selected provider base prefix
- **AND THEN** the script creates a backup of the existing config before deleting

### Requirement: Security Hygiene
The system SHALL write the OpenCode configuration file with restrictive permissions and SHALL avoid destructive overwrites by default.

#### Scenario: Restrictive permissions
- **WHEN** the script writes `opencode.json`
- **THEN** the file is written with permissions equivalent to `0600` where supported

#### Scenario: No unintended overwrites
- **WHEN** the existing OpenCode config cannot be safely merged (for example, missing JSON tooling)
- **THEN** the script aborts or requires explicit user confirmation before overwriting the full file
