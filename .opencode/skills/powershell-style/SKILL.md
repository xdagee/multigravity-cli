---
name: powershell-style
description: PowerShell coding style conventions for Windows PowerShell 5.1+
license: MIT
compatibility: opencode
metadata:
  audience: contributors
  language: powershell
---

## What I do

Enforce consistent PowerShell coding style following project conventions.

## When to use me

Use this when writing, editing, or reviewing PowerShell code in this project.

## Coding Standards

### Indentation
- Use **2 spaces** for indentation inside functions (not tabs)
- Align `param()` block parameters for readability

### Naming Conventions

| Type | Convention | Examples |
|------|------------|----------|
| Functions | `PascalCase` verb-noun | `New-Profile`, `Get-ProfileMetadata` |
| Parameters | `PascalCase` | `$Name`, `$Theme`, `$FontSize` |
| Variables | `$PascalCase` or `$camelCase` | `$profileRoot`, `$runningInstances` |
| Constants | `$CamelCase` | `$AppName`, `$DataRoot` |
| Switches | `$PascalCase` | `$Force`, `$SilentlyLaunch` |

### Approved Verbs

Use standard PowerShell verbs:
- `Get`, `Set`, `New`, `Remove` - CRUD operations
- `Start`, `Stop` - Process management
- `Write`, `Read`, `Save` - I/O operations
- `Test`, `Validate`, `Ensure` - Validation
- `Fail`, `FailWith` - Error handling
- `Resolve`, `Initialize` - Setup operations

### Function Structure

```powershell
function Verb-Noun {
  param(
    [string]$RequiredParam,
    [string]$OptionalParam = $null,
    [switch]$Flag
  )
  
  # Guard clauses first
  if (-not $SomeCondition) {
    return
  }
  
  # Main logic
  ...
}
```

### Error Handling

Use the `Fail` helper for user-facing errors (defined in multigravity.ps1:61):
```powershell
function Fail {
  param([string]$Message)
  Write-Log -Level 'error' -Message $Message
  throw $Message
}
```

Use `try/catch` for operations that may fail legitimately:
```powershell
try {
  $process = Get-Process -Id $processId -ErrorAction Stop
} catch {
  Write-Log -Level 'info' -Message "Removing stale instance record."
}
```

### Path Handling

- Use `Join-Path` for all path construction
- Use `$PSScriptRoot` for script-relative paths
- Never hardcode paths like `C:\Program Files`

### JSON Operations

- **Read**: Use `Read-JsonFile` helper (returns `$null` if missing/empty)
- **Write**: Use `Save-JsonFile` helper with `ConvertTo-Json -Depth 8`
- **Encoding**: Always use `-Encoding UTF8`

### Credential Storage

- **Use Windows DPAPI** via `Export-Clixml`/`Import-Clixml`
- **Never store plaintext credentials**
- Store at `Join-Path (Get-ProfilePath -Name $Name) 'credential.xml'`

### Profile Name Validation

Always validate profile names:
```powershell
if ($Name -notmatch '^[A-Za-z0-9][A-Za-z0-9-]*$') {
  Fail 'Profile names must start with alphanumeric and contain only letters, numbers, or hyphens.'
}
```

### Destructive Operations

- Require `-Force` switch for destructive commands
- Never broaden file deletion beyond `%LOCALAPPDATA%\Multigravity\profiles\<name>`
- Log all destructive actions via `Write-Log`
