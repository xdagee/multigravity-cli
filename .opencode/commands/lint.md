---
description: Check code style and patterns
agent: build
model: opencode/zen
---

Check PowerShell code style by examining key patterns:

1. Run help to verify CLI parsing works:
```powershell
powershell -ExecutionPolicy Bypass -File .\multigravity.ps1 help
```

2. Check for common style issues in PowerShell files:
- Look for inconsistent indentation
- Check naming conventions
- Verify error handling patterns
- Review path handling

3. Run tests to ensure no regressions:
```powershell
Invoke-Pester -Path .\tests\Multigravity.Core.Tests.ps1
```

Report any issues found and suggest fixes.
