# Repository Guidelines

## Project Overview

**Multigravity** is a Windows CLI tool for managing multiple Antigravity profiles. Each profile has isolated app data, settings, extensions, and optional stored credentials.

### File Structure

| File | Purpose |
|------|---------|
| `multigravity.ps1` | Main CLI entry point (~1310 lines). Contains all commands, UI, and profile logic. |
| `multigravity.core.psm1` | PowerShell module with shared helper functions. |
| `multigravity.cmd` | Thin command wrapper for launching the PowerShell script. |
| `install-windows.ps1` | Installs launcher to user-local Windows location. |
| `tests/` | Pester test suite for module functions. |
| `packaging/chocolatey/` | Chocolatey package configuration. |
| `docs/` | Documentation (testing-plan.md, acceptance-criteria.md, how-it-works.md). |
| `assets/` | Static assets (icons). |

---

## Build, Lint, and Test Commands

### Running the CLI

```powershell
# Full help output (tests CLI parsing)
powershell -ExecutionPolicy Bypass -File .\multigravity.ps1 help

# Profile management commands
powershell -ExecutionPolicy Bypass -File .\multigravity.ps1 profile new test-profile --theme=Dark
powershell -ExecutionPolicy Bypass -File .\multigravity.ps1 profile list
powershell -ExecutionPolicy Bypass -File .\multigravity.ps1 profile rename test-profile test-profile-2
powershell -ExecutionPolicy Bypass -File .\multigravity.ps1 profile delete test-profile-2 -Force

# Other commands
powershell -ExecutionPolicy Bypass -File .\multigravity.ps1 doctor
powershell -ExecutionPolicy Bypass -File .\multigravity.ps1 config set-app "C:\Path\To\Antigravity.exe"
powershell -ExecutionPolicy Bypass -File .\multigravity.ps1 install-windows.ps1
```

### Running Tests

**Prerequisites:** Pester 5.x must be installed (PowerShell Core recommended):
```powershell
pwsh -Command "Install-Module -Name Pester -Force -SkipPublisherCheck -MinimumVersion 5.0 -Scope CurrentUser"
```

**Run all tests:**
```powershell
pwsh -Command "Invoke-Pester"
```

**Run with detailed output:**
```powershell
pwsh -Command "Invoke-Pester -Output Detailed"
```

**Run a single test file:**
```powershell
pwsh -Command "Invoke-Pester -Path .\tests\Multigravity.Core.Tests.ps1"
```

**Run tests with code coverage:**
```powershell
pwsh -Command "Invoke-Pester -Path .\tests -CodeCoverage .\multigravity.core.psm1"
```

**Use default configuration** (if `tests/pester.config.ps1` exists):
```powershell
pwsh -Command "Invoke-Pester"
```

**Run specific test by name:**
```powershell
pwsh -Command "Invoke-Pester -Path .\tests -Filter 'Resolve-AntigravityExecutablePath'"
```

---

## Coding Style Guidelines

### General Principles

- **Windows-specific**: All code must run on Windows 10/11 with PowerShell 5.1+.
- **No compiled build step**: This is pure PowerShell; scripts run directly.
- **Small functions**: Prefer focused functions over long inline logic. Extract reusable patterns.
- **Defensive file operations**: Always check `Test-Path` before reading/writing.

### Indentation and Formatting

- **2 spaces** for indentation inside functions (not tabs).
- Align `param()` block parameters for readability.
- Use splatting for cmdlets with 3+ parameters.

```powershell
# Good
function Start-Antigravity {
  param(
    [string]$Name,
    [switch]$Switch,
    [string[]]$ExtraArguments
  )
  $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = $exePath
  ...

# Avoid
function Start-Antigravity {
param(
[string]$Name,[switch]$Switch,[string[]]$ExtraArguments
)
```

### Naming Conventions

| Type | Convention | Examples |
|------|------------|----------|
| Functions | `PascalCase` verb-noun | `New-Profile`, `Get-ProfileMetadata`, `Start-Antigravity` |
| Parameters | `PascalCase` | `$Name`, `$Theme`, `$FontSize` |
| Variables | `$PascalCase` or `$camelCase` | `$profileRoot`, `$runningInstances` |
| Constants | `$CamelCase` | `$AppName`, `$DataRoot` |
| Switches | `$PascalCase` | `$Force`, `$SilentlyLaunch` |

**Approved Verbs**: Use standard PowerShell verbs (`Get`, `Set`, `New`, `Remove`, `Start`, `Write`, `Read`, `Save`, `Test`, `Fail`, `Ensure`, `Initialize`, `Resolve`, `Validate`).

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

- **Use `Fail` helper** for user-facing errors (defined in `multigravity.ps1:61`):
  ```powershell
  function Fail {
    param([string]$Message)
    Write-Log -Level 'error' -Message $Message
    throw $Message
  }
  ```

- **Use `try/catch`** for operations that may fail legitimately:
  ```powershell
  try {
    $process = Get-Process -Id $processId -ErrorAction Stop
    ...
  } catch {
    Write-Log -Level 'info' -Message "Removing stale instance record for PID $processId."
  }
  ```

- **Never expose raw exceptions** to end users; catch and format friendly messages.

- **Set strict mode and error preference** at script start:
  ```powershell
  Set-StrictMode -Version Latest
  $ErrorActionPreference = 'Stop'
  ```

### Profile Name Validation

Validate all profile names against this pattern:
```powershell
if ($Name -notmatch '^[A-Za-z0-9][A-Za-z0-9-]*$') {
  Fail 'Profile names must start with alphanumeric and contain only letters, numbers, or hyphens.'
}
```

Valid examples: `work`, `client-a`, `test1`
Invalid examples: `-work`, `profile_name`, `profile.name`

### JSON Storage

- **Read**: Use `Read-JsonFile` helper (returns `$null` if missing/empty).
- **Write**: Use `Save-JsonFile` helper with `ConvertTo-Json -Depth 8`.
- **Encoding**: Always use `-Encoding UTF8`.

### Credential Storage

- **Use Windows DPAPI** via `Export-Clixml`/`Import-Clixml`.
- **Never store plaintext credentials** or replace DPAPI with alternatives.
- Store at `Join-Path (Get-ProfilePath -Name $Name) 'credential.xml'`.

### Path Handling

- Use `Join-Path` for all path construction (handles backslashes correctly on Windows).
- Use `$PSScriptRoot` for script-relative paths.
- Never hardcode paths like `C:\Program Files`.

### Destructive Operations

- `Remove-Profile` must confirm unless `-Force` is specified.
- Never broaden file deletion beyond `%LOCALAPPDATA%\Multigravity\profiles\<name>`.
- Log all destructive actions via `Write-Log`.

### CLI Argument Parsing

Arguments are passed via `$Args` array. Use helper functions:
- `Get-OptionValue -Tokens $Args -Name 'theme'` returns the value after `--theme=`
- `Has-Option -Tokens $Args -Name 'font-size'` checks for presence

### Module Export

In `.psm1` files, explicitly list exported functions:
```powershell
Export-ModuleMember -Function Resolve-AntigravityExecutablePath, Get-UiActionState
```

---

## Testing Guidelines

### Test Framework

Uses **Pester 5.x** for testing. Key patterns:
- `BeforeAll` for setup (runs once before all tests in a Describe block)
- `It` for individual test cases
- `Should` assertions
- `$TestDrive` for auto-cleaned temporary directories

**Note:** Use `pwsh` (PowerShell Core) to run Pester 5.x tests, as the Windows PowerShell 5.1 bundled Pester is version 3.x.

### Writing Tests

```powershell
BeforeAll {
  $testRoot = Join-Path $TestDrive 'antigravity'
  New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
}

It 'accepts a direct executable path' {
  $resolved = Resolve-AntigravityExecutablePath -Path $exePath
  $resolved | Should Be (Resolve-Path $exePath).Path
}

It 'throws when the path is blank' {
  { Resolve-AntigravityExecutablePath -Path '' } | Should Throw 'Path is required.'
}
```

### Manual Verification Checklist

Until automated tests cover more:
- [ ] `profile new` creates `%LOCALAPPDATA%\Multigravity\profiles\<name>`
- [ ] `profile rename` updates folder and profile.json
- [ ] `profile delete` removes folder (with and without `-Force`)
- [ ] `launch` fails cleanly when Antigravity.exe is missing
- [ ] `launch` fails cleanly when Antigravity.exe path is misconfigured
- [ ] Tray icon appears and menu works
- [ ] Shortcuts are created/removed correctly

See `docs/testing-plan.md` for full matrix.

---

## Commit & Pull Request Guidelines

### Commit Messages

Follow Conventional Commits:
```
<type>: <short description>

Types: feat, fix, docs, style, refactor, test, chore
```

Examples:
```
feat: add tray icon with profile switching
fix: handle missing Antigravity.exe gracefully
docs: add troubleshooting section to README
```

### Pull Request Checklist

- [ ] Brief description of changes
- [ ] Windows versions tested (10, 11)
- [ ] Manual test notes
- [ ] Screenshots for UI/tray changes only

---

## Platform & Safety Notes

- **Windows only**: Do not add cross-platform code.
- **Credential storage**: DPAPI via `Export-Clixml` is mandatory; no plaintext.
- **Destructive paths**: Restrict `Remove-Item` to known profile directories.
- **Logging**: Use `Write-Log` for all significant operations.
- **Shortcuts**: Only create in Start Menu `Multigravity` folder.
