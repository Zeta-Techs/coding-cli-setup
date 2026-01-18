## Context
This repository configures multiple third-party CLIs by writing local config files and/or environment variables.

OpenCode config is stored in `opencode.json` under an XDG-style directory. The current implementation writes base URLs and API keys into provider definitions, which conflicts with the preferred OpenCode workflow: users should use OpenCode's `/connect` to attach API keys to providers.

The requested change also adds multi-provider support, which means OpenCode config mutations must be non-destructive: existing providers and any user-customized `models` blocks must be preserved.

## Goals / Non-Goals
- Goals:
  - Configure OpenCode providers to point at ZetaTechs base URLs without writing secrets.
  - Support multiple provider groups (multiple prefixes), each group containing openai/claude/gemini.
  - Avoid destructive overwrites by default; always back up before any destructive operation.
  - Keep cross-platform behavior consistent between Bash and PowerShell.
- Non-Goals:
  - Validating provider API keys (handled by OpenCode).
  - Reformatting or normalizing all of `opencode.json` beyond the fields we manage.

## Decisions
- Provider grouping and IDs
  - Treat a "provider group" as a shared base prefix with three provider IDs:
    - `<base>-openai`
    - `<base>-claude`
    - `<base>-gemini`
  - Detect existing groups by scanning provider IDs ending with `-openai|-claude|-gemini` and extracting the `<base>` prefix.

- Add vs update behavior
  - Add:
    - Prompt for a new provider base prefix.
    - Create (or upsert) the three provider entries for that base.
    - Do not modify any other provider entries.
  - Update:
    - Prompt the user to select one existing provider base prefix.
    - Update only that group's `options.baseURL` fields.
    - Do not touch other groups.

- API key handling
  - The setup scripts will no longer prompt for API keys for OpenCode.
  - When updating providers, do not delete or overwrite any existing `options.apiKey` values.
  - When creating new providers, omit `options.apiKey` entirely.
  - Print guidance: "Open OpenCode and run `/connect`, select the provider, and enter the API key".

- JSON mutation strategy
  - PowerShell:
    - Use `ConvertFrom-Json` / `ConvertTo-Json -Depth ...` to safely update provider objects.
    - Preserve unknown keys.
    - Write UTF-8 without BOM.
  - Bash:
    - Use `jq` when available to safely upsert provider blocks.
    - If `jq` is missing or the existing JSON is invalid:
      - Allow creating a new file (no merge needed).
      - For an existing file, default to aborting unless the user explicitly confirms a full overwrite.

- Listing and deletion
  - After setup, print a list of all provider IDs found under `.provider`.
  - Provide an optional delete flow for a provider group (the three IDs for a selected base prefix), with confirmation and backup.

## Risks / Trade-offs
- Bash without `jq`
  - Safe, non-destructive multi-provider editing is hard without a JSON parser.
  - Mitigation: require `jq` for in-place edits of an existing file; otherwise abort or ask for explicit overwrite.

- Config shape differences
  - Some users may have provider entries that do not follow our `-openai|-claude|-gemini` convention.
  - Mitigation: only operate on the provider IDs/groups the user selects; never delete or rewrite unrelated providers.

## Migration Plan
- Backward compatible by default:
  - Existing OpenCode configs that already contain `options.apiKey` will keep those values.
  - Re-running setup only updates baseURL for the selected group.
- Potential breaking behavior:
  - The script will stop collecting OpenCode API keys.
  - Users must use OpenCode `/connect` for API key setup.

## Open Questions
- None. Deletion is scoped to provider groups only (delete the three IDs for a selected base prefix).
