## ADDED Requirements

### Requirement: OpenCode Config Target
The system SHALL provide an interactive setup path to configure OpenCode (opencode) to use a user-selected ZetaTechs API base URL and API key.

#### Scenario: User selects OpenCode setup
- **WHEN** the user selects OpenCode (opencode) from the setup menu
- **THEN** the setup flow prompts for site selection and credentials

### Requirement: OpenCode Config File Location
The system SHALL write OpenCode configuration to the XDG config location.

If the config file does not exist, the system SHALL create it using a full provider template compatible with the OpenCode config schema and populate `provider.*.options.baseURL` and `provider.*.options.apiKey`.

#### Scenario: macOS/Linux/WSL path
- **WHEN** the user runs the Bash setup script
- **THEN** the script writes to `~/.config/opencode/opencode.json`

#### Scenario: Windows path
- **WHEN** the user runs the PowerShell setup script
- **THEN** the script writes to `%USERPROFILE%\.config\opencode\opencode.json`

### Requirement: Provider Definitions
The system SHALL configure one or more ZetaTechs provider definitions in `opencode.json`.

Provider ID naming convention:
- Default (main) site: `zetatechs-api-<suffix>`
- Enterprise site: `zetatechs-api-enterprise-<suffix>`
- Custom base URL: the setup flow SHALL prompt for a custom provider base name; the provider IDs SHALL be `<custom-name>-<suffix>`
- `<suffix>` SHALL be one of: `openai`, `claude`, `gemini`

#### Scenario: Provider blocks exist
- **WHEN** setup completes successfully
- **THEN** `opencode.json` contains provider objects for ZetaTechs using provider IDs following the selected site naming convention

#### Scenario: Custom base URL provider base name
- **WHEN** the user selects a custom base URL
- **THEN** the setup flow prompts the user for an OpenCode provider base name to use for provider IDs

### Requirement: Provider Base URL
The system SHALL set `provider.<id>.options.baseURL` to the appropriate base URL for the selected site.

#### Scenario: OpenAI/Claude use /v1
- **WHEN** the user selects a site preset (or provides a custom base URL)
- **THEN** the OpenAI and Claude providers use a base URL ending in `/v1`

#### Scenario: Gemini uses /v1beta
- **WHEN** the user selects a site preset (or provides a custom base URL)
- **THEN** the Gemini provider uses a base URL ending in `/v1beta`

### Requirement: Provider API Key
The system SHALL set `provider.<id>.options.apiKey` to the user-provided API key.

#### Scenario: API key updated
- **WHEN** the user provides a new API key
- **THEN** the configured ZetaTechs provider(s) have `options.apiKey` set to that value

### Requirement: Idempotent Re-Run
The system SHALL preserve existing OpenCode configuration values when the user presses Enter to keep current settings.

#### Scenario: Keep existing base URL and key
- **WHEN** an existing OpenCode configuration already contains ZetaTechs provider(s)
- **AND WHEN** the user presses Enter at the base URL prompt and at the API key prompt
- **THEN** the script does not change the existing base URL and API key values

#### Scenario: Do not rewrite models
- **WHEN** `opencode.json` already contains model definitions under a managed provider
- **THEN** the setup flow only updates `provider.<id>.options.baseURL` and `provider.<id>.options.apiKey`
- **AND THEN** existing `models` content remains unchanged

### Requirement: Security Hygiene
The system SHALL not print full API keys to stdout and SHALL write the OpenCode configuration file with restrictive permissions.

#### Scenario: No secret echoed
- **WHEN** the user provides an API key
- **THEN** the script does not print the full API key value

#### Scenario: Restrictive permissions
- **WHEN** the script writes `opencode.json`
- **THEN** the file is written with permissions equivalent to `0600` where supported
