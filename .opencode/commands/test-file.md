---
description: Run Pester tests for a specific test file
agent: build
model: opencode/zen
---

Run Pester tests for a specific test file in this Multigravity project.

The test file to run is: $ARGUMENTS

Execute this command:
```powershell
Invoke-Pester -Path "$ARGUMENTS" -Output Detailed
```

If no file is provided (empty $ARGUMENTS), default to:
```powershell
Invoke-Pester -Path .\tests\Multigravity.Core.Tests.ps1 -Output Detailed
```

After running, provide:
1. Test pass/fail summary
2. Any failing test details
3. Recommendations for fixes if needed
