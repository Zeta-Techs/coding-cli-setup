## Context
This repository configures multiple third-party coding CLIs across Bash (macOS/Linux/WSL) and PowerShell (Windows). Configuration state is persisted in two different forms:
- Tool config files (OpenCode, Codex, Factory Droid)
- Environment variable settings (Anthropic)

The requested behavior is to add a consistent "restore default settings" option so users can remove the configured values and return each tool to software defaults without manual file/env cleanup.

## Goals / Non-Goals
- Goals:
  - Provide a restore-default option for every setup target currently supported by each script.
  - Require explicit destructive confirmation before removing settings.
  - Preserve recoverability via backups for file deletions.
  - Keep normal add/update flows unchanged.
- Non-Goals:
  - Expanding target support (for example, adding Codex to Windows PowerShell).
  - Resetting unrelated user customizations outside managed files/keys.
  - Archiving or deleting parent directories when only specific files are managed.

## Decisions
- Decision: Add a per-target action selection that includes restore-default.
  - Rationale: Users asked for this option during provider setup; placing it in each target flow avoids hidden post-step operations.

- Decision: Use storage-specific reset behavior.
  - File-based targets (OpenCode, Codex, Factory): backup then delete managed file(s).
  - Env-based target (Anthropic): remove managed variables from the persistence mechanism used by each platform.
  - Rationale: This matches how each target is configured today and avoids introducing a generic abstraction that would complicate scripts.

- Decision: Keep resets idempotent and non-failing when nothing is set.
  - If target files/variables are already absent, return success and print an "already at defaults" message.
  - Rationale: Aligns with script conventions that re-runs are safe.

- Decision: Require explicit destructive confirmation.
  - Rationale: Reset may remove user-customized settings in managed files; explicit confirmation prevents accidental data loss.

## Risks / Trade-offs
- Risk: Deleting full config files may remove unrelated user edits inside those files.
  - Mitigation: Always create timestamped backup before deletion and clearly communicate backup path.

- Risk: Anthropic variable removal must differ by platform.
  - Mitigation: Bash removes managed export lines in shell rc files; PowerShell removes user-level environment variables.

- Risk: UX inconsistency if prompt wording differs between scripts.
  - Mitigation: define one confirmation pattern and mirror it in both scripts.

## Migration Plan
1. Add spec deltas for OpenCode action menu update and cross-tool default-reset behavior.
2. Implement Bash target resets, then PowerShell target resets.
3. Run manual smoke tests for confirmed reset, canceled reset, and already-default cases.
4. Update any user-facing docs if needed during implementation.

## Open Questions
- None.
