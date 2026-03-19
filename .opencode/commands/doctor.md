---
description: Run Multigravity diagnostics
agent: build
model: opencode/zen
---

Run the Multigravity doctor command to check diagnostics:

```powershell
powershell -ExecutionPolicy Bypass -File .\multigravity.ps1 doctor
```

This shows:
- Data root path
- Number of profiles
- Configured Antigravity path
- Running instance count
- Log file location

Report the results and note any potential issues.
