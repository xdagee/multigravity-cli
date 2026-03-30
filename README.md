# Multigravity for Windows

Multigravity lets you run Antigravity with separate profiles on Windows 10 and Windows 11.

Each profile keeps its own app data, settings, extensions, and optional saved credentials, so you can stay signed into different accounts and switch quickly.

## Quick Start
```powershell
powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
multigravity config set-app "C:\Users\<you>\AppData\Local\Programs\Antigravity"
multigravity
```

`multigravity` opens a small profile window. You do not need to learn commands to use the basics.

## What You Do
1. Click `Locate App` if the app path is not set yet.
2. Click `New` and enter a profile name like `work` or `personal`.
3. Double-click a profile to open it.
4. Click `Switch` to jump back to a profile that is already running.
5. Click `Delete` if you want to remove a profile and its data.
6. Click `Save Login` only if you want encrypted credentials stored for that profile.

## How It Works
- Each profile lives in `%LOCALAPPDATA%\Multigravity\profiles\<name>`.
- Multigravity starts Antigravity with a separate user-data folder and extensions folder for that profile.
- If the profile is already running, Multigravity brings that window to the front instead of opening a duplicate.
- Logs and launcher settings live in `%LOCALAPPDATA%\Multigravity`.

## Advanced Commands
```powershell
multigravity ui
multigravity profile list
multigravity launch work --account user@example.com
multigravity switch work
multigravity credential set work --account user@example.com
multigravity credential list work
multigravity credential set-default work --account user@example.com
multigravity tray
multigravity doctor
```

Profile names accept letters, numbers, and hyphens only.

## Multiple Accounts

Each profile can store multiple credentials:
```powershell
# Store credentials for different accounts
multigravity credential set work --account work@example.com
multigravity credential set work --account personal@example.com

# Set default account for profile
multigravity credential set-default work --account work@example.com

# List all stored accounts
multigravity credential list work

# Launch with specific account
multigravity launch work --account work@example.com
```

## More Help
- User guide: `docs/how-it-works.md`
- Acceptance criteria: `docs/acceptance-criteria.md`
- Test plan: `docs/testing-plan.md`
- Contributor guide: `AGENTS.md`

## Notes
- Credentials are optional and stored with Windows DPAPI, not plain text.
- Chocolatey packaging sources live under `packaging/chocolatey/`.
- The UI is intentionally minimal. The CLI remains available for advanced use.
