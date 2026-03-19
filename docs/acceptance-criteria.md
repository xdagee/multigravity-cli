# Acceptance Criteria

## Minimal UI
1. Running `multigravity` with no arguments opens the minimal profile window.
2. If no profiles exist, `Open`, `Switch`, `Delete`, and `Save Login` are disabled.
3. If no profiles exist, the footer says: `No profiles yet. Click New to create your first one.`
4. After `Locate App`, Multigravity offers to create the first profile if none exist.
5. After at least one profile exists and one is selected, `Open`, `Switch`, `Delete`, and `Save Login` are enabled.

## Path Configuration
1. `multigravity config set-app <folder>` accepts the Antigravity install directory and resolves `Antigravity.exe`.
2. `multigravity config set-app <full-exe-path>` accepts the direct executable path.
3. Invalid paths fail with a clear `Antigravity.exe not found` message.

## Test Standard
1. `tests/Multigravity.Core.Tests.ps1` passes.
2. The module `multigravity.core.psm1` is executed with 100% line coverage by the Pester run that targets it.
