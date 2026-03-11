# Design: Conform project fmt fallback

Date: 2026-03-11

## Overview
Implement formatting behavior in Neovim conform so that, when the repository root
`package.json` defines a `scripts.fmt` command, conform runs that command for
formatting. If the script is missing or cannot be used, formatting falls back to
LSP formatting.

## Architecture
- Location: `nvim/.config/nvim/lua/plugins/development.lua`
- Add a custom conform formatter (e.g., `project_fmt`).
- `format_on_save` determines whether to run the formatter or fall back to LSP.

## Data Flow
1. Resolve repository root for the current buffer.
2. Read repository-root `package.json`.
3. If `scripts.fmt` exists:
   - Detect package manager via lockfiles.
   - Run `<pm> run fmt` at repo root via conform formatter.
4. If `scripts.fmt` does not exist or parsing fails: return `{ lsp_fallback = true }`.

## Error Handling
- Missing/invalid `package.json` → fallback to LSP.
- Missing `scripts.fmt` → fallback to LSP.
- Formatter command fails → notify and allow LSP fallback (implementation detail).

## Testing
- Repo with `scripts.fmt`: save a file and confirm the formatter runs.
- Repo without `scripts.fmt`: save a file and confirm LSP formatting runs.
