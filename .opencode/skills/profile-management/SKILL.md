---
name: profile-management
description: Profile management workflows for Multigravity CLI
license: MIT
compatibility: opencode
metadata:
  audience: contributors
  domain: cli-commands
---

## What I do

Provide guidance for implementing profile management commands and workflows.

## When to use me

Use this when implementing profile-related features like creation, renaming, deletion, or profile settings.

## Profile Architecture

Each profile lives at:
```
%LOCALAPPDATA%\Multigravity\profiles\<name>
```

Profile structure:
```
<profile-name>/
├── profile.json          # Metadata (name, theme, fontSize, keybindings, extensions)
├── credential.xml        # Encrypted credentials (optional, DPAPI)
├── AppData/
│   ├── Roaming/          # %APPDATA% isolation
│   ├── Local/            # %LOCALAPPDATA% isolation
│   └── Temp/             # %TEMP% isolation
├── UserData/             # Antigravity user data folder
│   ├── settings.json     # Theme and font preferences
│   └── keybindings.json  # Profile-specific keybindings
├── Extensions/          # Isolated extensions
└── Logs/                # Profile-specific logs
```

## Profile JSON Schema

```powershell
@{
    name = $Name
    createdAt = (Get-Date).ToString('o')
    settings = @{
        theme = $Theme
        fontSize = if ($FontSize -gt 0) { $FontSize } else { $null }
        keybindings = $Keybindings
    }
    extensions = @($Extensions)
    appPathOverride = $null
}
```

## Key Functions

### Profile Creation (`New-Profile`)
1. Validate profile name with `Validate-ProfileName`
2. Check if profile already exists
3. Create directory structure with `Ensure-ProfileStructure`
4. Save profile metadata with `Save-ProfileMetadata`
5. Write user files with `Write-UserFiles`

### Profile Deletion (`Remove-Profile`)
1. Validate profile name
2. Check if profile exists
3. Require `-Force` or prompt for confirmation
4. Remove profile directory
5. Remove associated shortcut
6. Remove instance records

### Profile Renaming (`Rename-Profile`)
1. Validate both old and new names
2. Check both profiles exist/do not exist
3. Move directory with `Move-Item`
4. Update `profile.json` name field

## CLI Argument Parsing

Arguments are passed via `$Args` array. Use helper functions:

```powershell
# Get value after --theme=Dark
Get-OptionValue -Tokens $Args -Name 'theme'

# Check for presence of --force
Has-Option -Tokens $Args -Name 'force'
```

## Profile Options

| Option | Type | Description |
|--------|------|-------------|
| `--theme` | string | Color theme name |
| `--font-size` | int | Editor font size |
| `--keybindings` | string | Keybindings profile name |
| `--extensions` | string | Comma-separated extension IDs |

## Testing Profile Features

When testing profile management:
1. Verify directory creation at correct path
2. Verify profile.json contents
3. Verify isolation (separate folders don't share data)
4. Test rename updates both folder and metadata
5. Test deletion removes all profile data
