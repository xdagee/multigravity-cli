---
name: pester-testing
description: Pester 5.x testing patterns for PowerShell modules
license: MIT
compatibility: opencode
metadata:
  audience: contributors
  test-framework: pester
---

## What I do

Guide proper Pester 5.x test writing for this PowerShell project.

## When to use me

Use this when writing or updating tests in the `tests/` directory.

## Prerequisites

Pester 5.x must be installed (PowerShell Core recommended):
```powershell
pwsh -Command "Install-Module -Name Pester -Force -SkipPublisherCheck -MinimumVersion 5.0 -Scope CurrentUser"
```

**Note:** Use `pwsh` (PowerShell Core) to run Pester 5.x tests. Windows PowerShell 5.1 ships with Pester 3.x.

## Test Framework Patterns

### Basic Structure

```powershell
Import-Module "$PSScriptRoot\..\multigravity.core.psm1" -Force

Describe 'FunctionName' {
  BeforeAll {
    # Setup - runs once before all tests
    $testRoot = Join-Path $TestDrive 'antigravity'
  }

  It 'test description' {
    # Test code
    $result | Should -Be $expected
  }
}
```

### Key Patterns

#### Using `$TestDrive`
- `$TestDrive` is an auto-cleaned temp directory for tests
- Each Describe block gets a fresh `$TestDrive`
- Files created here are automatically cleaned up

#### Testing Throws
```powershell
It 'throws when path is blank' {
  { Resolve-AntigravityExecutablePath -Path '' } | Should -Throw 'Path is required.'
}
```

#### Testing Exceptions with Specific Messages
```powershell
It 'throws descriptive error when file missing' {
  try {
    Resolve-AntigravityExecutablePath -Path 'missing.exe'
    throw 'Expected exception'
  } catch {
    $_.Exception.Message.StartsWith('Antigravity.exe not found:') | Should -Be $true
  }
}
```

#### Testing Output
```powershell
It 'outputs expected format' {
  $output = & { ... } 2>&1  # Capture output
  $output | Should -Match 'pattern'
}
```

### Migration from Pester 3.x

Pester 5.x requires **dash syntax** for `Should`:
- `Should Be` → `Should -Be`
- `Should Throw` → `Should -Throw`
- `Should Match` → `Should -Match`
- `Should -Be $true` → `Should -Be $true`

## Running Tests

**Important:** Always use `pwsh` (PowerShell Core) to run Pester 5.x.

### All Tests
```powershell
pwsh -Command "Invoke-Pester"
```

### With Detailed Output
```powershell
pwsh -Command "Invoke-Pester -Output Detailed"
```

### Single Test File
```powershell
pwsh -Command "Invoke-Pester -Path .\tests\Multigravity.Core.Tests.ps1"
```

### Run Specific Test by Name
```powershell
pwsh -Command "Invoke-Pester -Path .\tests -Filter 'FunctionName'"
```

### With Coverage Report
```powershell
pwsh -Command "Invoke-Pester -Path .\tests -CodeCoverage .\multigravity.core.psm1"
```

### Use Default Configuration
If `tests/pester.config.ps1` exists:
```powershell
pwsh -Command "Invoke-Pester"
```

## Test Organization

| File | Tests |
|------|-------|
| `tests/Multigravity.Core.Tests.ps1` | Core module functions |

## What to Test

### Input Validation
- Empty/null inputs
- Invalid format (e.g., invalid profile names)
- Missing required files/paths

### Happy Path
- Valid inputs produce expected outputs
- Files created at correct locations
- JSON serialized correctly

### Error Handling
- Descriptive error messages
- Logging for recoverable errors
- Clean failures for fatal errors

## Module Import Pattern

Always import the module under test:
```powershell
Import-Module "$PSScriptRoot\..\multigravity.core.psm1" -Force
```

For `multigravity.ps1` tests, you may need to dot-source or use a test harness.
