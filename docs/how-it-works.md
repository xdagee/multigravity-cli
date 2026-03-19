# How Multigravity Works

Multigravity lets you run Antigravity with separate profiles on the same Windows PC.

Each profile gets its own private data folder under:

`%LOCALAPPDATA%\Multigravity\profiles\<profile-name>`

That folder holds the profile's:

- Antigravity user data
- extensions
- local app data
- roaming app data
- optional encrypted credentials

## What happens when you open a profile

When you open a profile, Multigravity:

1. Finds `Antigravity.exe`
2. Creates the profile folder if it does not already exist
3. Starts Antigravity with a profile-specific `--user-data-dir`
4. Starts Antigravity with a profile-specific `--extensions-dir`
5. Tracks the running process so it can switch back to it later

Because each profile uses its own data folders, accounts, settings, and extensions stay separate.

## How switching works

If a profile is already running, Multigravity tries to bring that Antigravity window to the front instead of starting another copy.

If it cannot find a running window for that profile, it launches the profile again.

## The simple UI

Running `multigravity` with no arguments opens a small window.

From that window you can:

- choose the Antigravity install location
- create a new profile
- open a profile
- switch to a running profile
- delete a profile
- store encrypted credentials
- search/filter profiles
- toggle between dark and light themes (auto-detects Windows setting)

### Keyboard Shortcuts

| Shortcut | Action |
|---------|--------|
| `Enter` | Open selected profile |
| `Delete` | Delete selected profile |
| `Ctrl+N` | Create new profile |
| `Ctrl+F` | Focus search box |
| `Escape` | Clear search / Close window |
| `Down Arrow` | Navigate from search to list |

### Toast Notifications

The UI shows toast notifications when:
- A profile is opened
- A profile is switched
- A profile is created
- A profile is deleted
- Credentials are saved
- An error occurs

### Right-Click Context Menu

Right-click on a profile to access:
- Open
- Switch To
- Delete

Double-clicking a profile opens it.

## Credentials

Credentials are optional.

If you save them, Multigravity stores them with Windows DPAPI using your Windows account, not as plain text.

## Where settings live

Global Multigravity settings live under:

`%LOCALAPPDATA%\Multigravity`

Important files:

- `settings.json` stores the Antigravity path and launcher options
- `instances.json` stores tracked running instances
- `logs\multigravity.log` stores launcher logs

## If something goes wrong

Use:

```powershell
multigravity doctor
```

This shows the data folder, configured Antigravity path, running instance count, and log file location.
