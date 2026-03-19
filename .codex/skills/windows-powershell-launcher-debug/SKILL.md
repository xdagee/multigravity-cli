---
name: windows-powershell-launcher-debug
description: Debug and verify Windows PowerShell CLI launchers, wrappers, installers, and process-switching utilities. Use when a PowerShell-based tool on Windows fails to launch correctly, cannot detect running processes, mishandles empty state or argument parsing, breaks under shell wrappers like cmd or powershell, or needs tight runtime verification after code changes.
---

# Windows Powershell Launcher Debug

## Overview

Read the launcher path end to end: main `.ps1`, wrapper `.cmd`, installer script, and the exact functions behind the failing command. Focus on runtime behavior, not just syntax.

Prefer the smallest command that proves a fix, such as `help`, `doctor`, `list`, or a single create/delete flow, before running broader end-to-end checks.

## Workflow

1. Inspect the failing path.
Read the function that owns the failure plus any wrapper or installer that feeds it arguments or environment state.

2. Reproduce narrowly.
Start with parser checks and the smallest runtime command that touches the failing code path.

3. Check PowerShell-specific traps.
- Arrays, single objects, and `$null`
- Property access on empty collections
- Reserved variables such as `$PID`
- Quoting through `cmd /c`, `powershell -Command`, and `-File`
- `UseShellExecute`, environment propagation, and window handles

4. Compare persisted state with live state.
If the tool tracks processes or windows, verify both saved state files and live process discovery from `Get-Process` or `Get-CimInstance Win32_Process`.

5. Patch the narrowest root cause.
Avoid broad rewrites when the problem is a collection check, quoting bug, stale PID record, or process lookup gap.

6. Rerun the exact failing command.
Only after it passes should broader verification be repeated.

## Common Fix Patterns

- Wrap collections at the call site with `@(...)` when count or indexing matters.
- Avoid using `$pid` as a local variable.
- Use explicit `Where-Object` filters instead of shorthand property access when collections may be empty.
- Rebuild stale launcher state from live process inspection, then persist the cleaned result.
- Verify installers in a temporary local folder before changing user-global locations.

## Useful Validation Commands

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool.ps1 help`
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool.ps1 doctor`
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool.ps1 list`
- `powershell -NoProfile -ExecutionPolicy Bypass -Command "[void][System.Management.Automation.Language.Parser]::ParseFile('tool.ps1',[ref]$tokens,[ref]$errors)"`
- `Get-CimInstance Win32_Process -Filter "Name = 'App.exe'"`

## Typical Triggers

- "This PowerShell launcher can't detect the app running."
- "My Windows CLI works in help but fails in doctor."
- "The cmd wrapper passes arguments incorrectly."
- "The installer works, but the launcher doesn't find existing processes."
- "Debug this PowerShell-based profile switcher on Windows."
