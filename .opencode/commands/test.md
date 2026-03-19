---
description: Run the full Pester test suite with coverage
agent: build
model: opencode/zen
---

Run the complete Pester test suite for this Multigravity project with coverage analysis.

Execute this command:
```powershell
Invoke-Pester -Path .\tests -CoveragePath .\multigravity.core.psm1 -Output Detailed
```

After running, analyze the results:
1. Report overall pass/fail status
2. Highlight any failing tests with their descriptions
3. Report coverage percentage
4. Suggest improvements for low coverage areas

If tests fail, focus on understanding why and provide specific recommendations for fixes.
