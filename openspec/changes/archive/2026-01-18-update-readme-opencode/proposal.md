# Change: Update README for OpenCode support

## Why
The repository README currently describes configuring "three" tools and instructs users to select apps (1/2/3), but the latest code now supports OpenCode (opencode) as an additional setup option. This mismatch can confuse users and increases support load.

## What Changes
- Update `README.md` to reflect OpenCode (opencode) support.
- Keep README primarily Chinese while adding brief English clarifications for the OpenCode-related additions.
- Update any counts/wording that imply only three tools are supported.
- Update usage instructions and Windows section to include the OpenCode option and config file paths.

## Impact
- Affected specs:
  - Proposed capability: `docs`
- Affected files:
  - `README.md`
- User-facing behavior:
  - Documentation-only change; no script behavior changes.
