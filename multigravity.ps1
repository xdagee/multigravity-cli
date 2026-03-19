[CmdletBinding()]
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$AppName = 'Multigravity'
$DataRoot = Join-Path $env:LOCALAPPDATA $AppName
$ProfilesRoot = Join-Path $DataRoot 'profiles'
$LogsRoot = Join-Path $DataRoot 'logs'
$SettingsPath = Join-Path $DataRoot 'settings.json'
$InstancesPath = Join-Path $DataRoot 'instances.json'
$DefaultExeCandidates = @(
  (Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'),
  (Join-Path ${env:ProgramFiles} 'Antigravity\Antigravity.exe'),
  (Join-Path ${env:ProgramFiles(x86)} 'Antigravity\Antigravity.exe')
) | Where-Object { $_ }

Import-Module (Join-Path $PSScriptRoot 'multigravity.core.psm1') -Force

function Ensure-Directory {
  param([string]$Path)
  if (-not (Test-Path $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function Initialize-Storage {
  Ensure-Directory $DataRoot
  Ensure-Directory $ProfilesRoot
  Ensure-Directory $LogsRoot

  if (-not (Test-Path $SettingsPath)) {
    $settings = @{
      antigravityPath = $null
      defaultArguments = @()
      launchTimeoutSeconds = 15
      passCredentialEnv = $false
    }
    Save-JsonFile -Path $SettingsPath -Value $settings
  }

  if (-not (Test-Path $InstancesPath)) {
    Save-JsonFile -Path $InstancesPath -Value @()
  }
}

function Write-Log {
  param(
    [string]$Level,
    [string]$Message
  )
  Initialize-Storage
  $line = '{0:u} [{1}] {2}' -f (Get-Date), $Level.ToUpperInvariant(), $Message
  Add-Content -Path (Join-Path $LogsRoot 'multigravity.log') -Value $line -Encoding UTF8
}

function Fail {
  param([string]$Message)
  Write-Log -Level 'error' -Message $Message
  throw $Message
}

function Read-JsonFile {
  param([string]$Path)
  if (-not (Test-Path $Path)) {
    return $null
  }

  $raw = Get-Content -Path $Path -Raw -Encoding UTF8
  if ([string]::IsNullOrWhiteSpace($raw)) {
    return $null
  }

  return $raw | ConvertFrom-Json
}

function Save-JsonFile {
  param(
    [string]$Path,
    [Parameter(Mandatory = $true)]$Value
  )
  $Value | ConvertTo-Json -Depth 8 | Set-Content -Path $Path -Encoding UTF8
}

function Get-Settings {
  Initialize-Storage
  return Read-JsonFile -Path $SettingsPath
}

function Save-Settings {
  param($Settings)
  Save-JsonFile -Path $SettingsPath -Value $Settings
}

function Resolve-AntigravityPath {
  $settings = Get-Settings
  if ($settings.antigravityPath -and (Test-Path $settings.antigravityPath)) {
    return $settings.antigravityPath
  }

  foreach ($candidate in $DefaultExeCandidates) {
    if (Test-Path $candidate) {
      $settings.antigravityPath = $candidate
      Save-Settings -Settings $settings
      return $candidate
    }
  }

  Fail "Antigravity.exe was not found. Run 'multigravity config set-app ""C:\Path\To\Antigravity.exe""'."
}

function Validate-ProfileName {
  param([string]$Name)
  if ([string]::IsNullOrWhiteSpace($Name)) {
    Fail 'Profile name is required.'
  }
  if ($Name -notmatch '^[A-Za-z0-9][A-Za-z0-9-]*$') {
    Fail 'Profile names must start with an alphanumeric character and contain only letters, numbers, or hyphens.'
  }
}

function Get-ProfilePath {
  param([string]$Name)
  Join-Path $ProfilesRoot $Name
}

function Get-ProfileMetadataPath {
  param([string]$Name)
  Join-Path (Get-ProfilePath -Name $Name) 'profile.json'
}

function Get-ProfileMetadata {
  param([string]$Name)
  $path = Get-ProfileMetadataPath -Name $Name
  if (-not (Test-Path $path)) {
    Fail "Profile '$Name' does not exist."
  }
  return Read-JsonFile -Path $path
}

function Save-ProfileMetadata {
  param(
    [string]$Name,
    $Profile
  )
  $path = Get-ProfileMetadataPath -Name $Name
  Save-JsonFile -Path $path -Value $Profile
}

function Ensure-ProfileStructure {
  param([string]$Name)
  $profileRoot = Get-ProfilePath -Name $Name
  Ensure-Directory $profileRoot
  Ensure-Directory (Join-Path $profileRoot 'AppData\Roaming')
  Ensure-Directory (Join-Path $profileRoot 'AppData\Local')
  Ensure-Directory (Join-Path $profileRoot 'Temp')
  Ensure-Directory (Join-Path $profileRoot 'UserData')
  Ensure-Directory (Join-Path $profileRoot 'UserData\User')
  Ensure-Directory (Join-Path $profileRoot 'Extensions')
  Ensure-Directory (Join-Path $profileRoot 'Logs')
}

function New-Profile {
  param(
    [string]$Name,
    [string]$Theme,
    [int]$FontSize,
    [string]$Keybindings,
    [string[]]$Extensions
  )
  Validate-ProfileName -Name $Name
  $profileRoot = Get-ProfilePath -Name $Name
  if (Test-Path $profileRoot) {
    Fail "Profile '$Name' already exists."
  }

  Ensure-ProfileStructure -Name $Name

  $profile = @{
    name = $Name
    createdAt = (Get-Date).ToString('o')
    settings = @{
      theme = $Theme
      fontSize = if ($FontSize -gt 0) { $FontSize } else { $null }
      keybindings = $Keybindings
    }
    extensions = @($Extensions | Where-Object { $_ })
    appPathOverride = $null
  }
  Save-ProfileMetadata -Name $Name -Profile $profile
  Write-UserFiles -Name $Name
  Write-Host "Created profile '$Name'."
}

function Write-UserFiles {
  param([string]$Name)
  $profile = Get-ProfileMetadata -Name $Name
  $userDir = Join-Path (Get-ProfilePath -Name $Name) 'UserData\User'

  $settings = @{}
  if ($profile.settings.theme) { $settings['workbench.colorTheme'] = $profile.settings.theme }
  if ($profile.settings.fontSize) { $settings['editor.fontSize'] = [int]$profile.settings.fontSize }

  $settings | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $userDir 'settings.json') -Encoding UTF8

  $keybindings = @()
  if ($profile.settings.keybindings) {
    $keybindings = @(
      @{
        key = 'ctrl+alt+shift+m'
        command = 'multigravity.profile'
        when = "profile:$($profile.settings.keybindings)"
      }
    )
  }
  $keybindings | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $userDir 'keybindings.json') -Encoding UTF8
}

function Get-ProfileNames {
  Initialize-Storage
  if (-not (Test-Path $ProfilesRoot)) {
    return @()
  }
  return @(Get-ChildItem -Path $ProfilesRoot -Directory | Select-Object -ExpandProperty Name | Sort-Object)
}

function List-Profiles {
  $names = @(Get-ProfileNames)
  if ($names.Count -eq 0) {
    Write-Host 'No profiles found.'
    return
  }

  $instances = @(Get-RunningInstances)
  foreach ($name in $names) {
    $profile = Get-ProfileMetadata -Name $name
    $status = if ((@($instances | Where-Object { $_.profile -eq $name })).Count -gt 0) { 'running' } else { 'stopped' }
    $theme = if ($profile.settings.theme) { $profile.settings.theme } else { '-' }
    $font = if ($profile.settings.fontSize) { [string]$profile.settings.fontSize } else { '-' }
    Write-Host ("{0,-20} {1,-8} theme={2} font={3}" -f $name, $status, $theme, $font)
  }
}

function Get-ProfileSummaries {
  $names = @(Get-ProfileNames)
  $instances = @(Get-RunningInstances)
  $summaries = @()

  foreach ($name in $names) {
    $profile = Get-ProfileMetadata -Name $name
    $summaries += [pscustomobject]@{
      Name = $name
      Status = if ((@($instances | Where-Object { $_.profile -eq $name })).Count -gt 0) { 'Running' } else { 'Stopped' }
      Theme = if ($profile.settings.theme) { $profile.settings.theme } else { '-' }
      FontSize = if ($profile.settings.fontSize) { [string]$profile.settings.fontSize } else { '-' }
      HasCredentials = Test-Path (Get-CredentialPath -Name $name)
    }
  }

  return @($summaries)
}

function Rename-Profile {
  param(
    [string]$OldName,
    [string]$NewName
  )
  Validate-ProfileName -Name $OldName
  Validate-ProfileName -Name $NewName

  $oldPath = Get-ProfilePath -Name $OldName
  $newPath = Get-ProfilePath -Name $NewName
  if (-not (Test-Path $oldPath)) {
    Fail "Profile '$OldName' does not exist."
  }
  if (Test-Path $newPath) {
    Fail "Profile '$NewName' already exists."
  }

  Move-Item -Path $oldPath -Destination $newPath
  $profile = Get-ProfileMetadata -Name $NewName
  $profile.name = $NewName
  Save-ProfileMetadata -Name $NewName -Profile $profile
  Write-Host "Renamed profile '$OldName' to '$NewName'."
}

function Remove-Profile {
  param(
    [string]$Name,
    [switch]$Force
  )
  Validate-ProfileName -Name $Name
  $profilePath = Get-ProfilePath -Name $Name
  if (-not (Test-Path $profilePath)) {
    Fail "Profile '$Name' does not exist."
  }

  if (-not $Force) {
    $answer = Read-Host "Delete profile '$Name' and its data? [y/N]"
    if ($answer -notmatch '^[Yy]$') {
      Write-Host 'Aborted.'
      return
    }
  }

  Remove-Item -Path $profilePath -Recurse -Force
  Remove-Shortcut -Name $Name -Quiet
  Remove-InstanceRecords -Profile $Name
  Write-Host "Deleted profile '$Name'."
}

function Set-Profile {
  param(
    [string]$Name,
    [string]$Theme,
    [Nullable[int]]$FontSize,
    [string]$Keybindings,
    [string[]]$Extensions
  )
  $profile = Get-ProfileMetadata -Name $Name
  if ($PSBoundParameters.ContainsKey('Theme')) { $profile.settings.theme = $Theme }
  if ($PSBoundParameters.ContainsKey('FontSize')) { $profile.settings.fontSize = $FontSize }
  if ($PSBoundParameters.ContainsKey('Keybindings')) { $profile.settings.keybindings = $Keybindings }
  if ($PSBoundParameters.ContainsKey('Extensions')) { $profile.extensions = @($Extensions) }
  Save-ProfileMetadata -Name $Name -Profile $profile
  Write-UserFiles -Name $Name
  Write-Host "Updated profile '$Name'."
}

function Get-CredentialPath {
  param([string]$Name)
  Join-Path (Get-ProfilePath -Name $Name) 'credential.xml'
}

function Set-ProfileCredential {
  param([string]$Name)
  [void](Get-ProfileMetadata -Name $Name)
  $credential = Get-Credential -Message "Enter Antigravity credentials for profile '$Name'"
  $path = Get-CredentialPath -Name $Name
  $credential | Export-Clixml -Path $path
  Write-Host "Stored encrypted credentials for '$Name'."
}

function Clear-ProfileCredential {
  param([string]$Name)
  $path = Get-CredentialPath -Name $Name
  if (Test-Path $path) {
    Remove-Item -Path $path -Force
  }
  Write-Host "Removed stored credentials for '$Name'."
}

function Get-ProfileCredential {
  param([string]$Name)
  $path = Get-CredentialPath -Name $Name
  if (Test-Path $path) {
    return Import-Clixml -Path $path
  }
  return $null
}

function Get-RunningInstances {
  Initialize-Storage
  $trackedInstances = @(Read-JsonFile -Path $InstancesPath)
  $trackedByPid = @{}
  foreach ($instance in $trackedInstances) {
    if ($instance -and $instance.pid) {
      $trackedByPid[[int]$instance.pid] = $instance
    }
  }

  $active = @()
  foreach ($snapshot in @(Get-AntigravityProcessSnapshots)) {
    $processId = [int]$snapshot.pid
    if ($trackedByPid.ContainsKey($processId)) {
      $instance = $trackedByPid[$processId]
    } else {
      $instance = @{
        pid = $processId
        profile = Get-ProfileNameFromCommandLine -CommandLine $snapshot.commandLine
        launchedAt = $null
      }
    }

    try {
      $process = Get-Process -Id $processId -ErrorAction Stop
      $instance | Add-Member -NotePropertyName processName -NotePropertyValue $process.ProcessName -Force
      $instance | Add-Member -NotePropertyName commandLine -NotePropertyValue $snapshot.commandLine -Force
      $instance | Add-Member -NotePropertyName executablePath -NotePropertyValue $snapshot.executablePath -Force
      $active += $instance
    } catch {
      Write-Log -Level 'info' -Message "Removing stale instance record for PID $processId."
    }
  }

  Save-JsonFile -Path $InstancesPath -Value @($active)
  return @($active)
}

function Get-ProfileNameFromCommandLine {
  param([string]$CommandLine)
  if ([string]::IsNullOrWhiteSpace($CommandLine)) {
    return $null
  }

  $normalized = $CommandLine.ToLowerInvariant()
  foreach ($profileName in @(Get-ProfileNames)) {
    $profileUserData = (Join-Path (Get-ProfilePath -Name $profileName) 'UserData').ToLowerInvariant()
    if ($normalized.Contains($profileUserData)) {
      return $profileName
    }
  }

  return $null
}

function Get-AntigravityProcessSnapshots {
  $configuredPath = $null
  try {
    $configuredPath = (Resolve-AntigravityPath).ToLowerInvariant()
  } catch {
    $configuredPath = $null
  }

  $snapshots = @()
  try {
    $cimProcesses = Get-CimInstance -ClassName Win32_Process -Filter "Name = 'Antigravity.exe'" -ErrorAction Stop
    foreach ($process in @($cimProcesses)) {
      $path = if ($process.ExecutablePath) { $process.ExecutablePath } else { $null }
      if ($configuredPath -and $path -and $path.ToLowerInvariant() -ne $configuredPath) {
        continue
      }

      $snapshots += @{
        pid = [int]$process.ProcessId
        commandLine = $process.CommandLine
        executablePath = $path
      }
    }
  } catch {
    foreach ($process in @(Get-Process -Name 'Antigravity' -ErrorAction SilentlyContinue)) {
      $snapshots += @{
        pid = [int]$process.Id
        commandLine = $null
        executablePath = $null
      }
    }
  }

  return @($snapshots | Sort-Object -Property pid -Unique)
}

function Save-InstanceRecord {
  param(
    [string]$Profile,
    [int]$Pid
  )
  $instances = Get-RunningInstances
  $filtered = @($instances | Where-Object { $_.pid -ne $Pid })
  $filtered += @{
    profile = $Profile
    pid = $Pid
    launchedAt = (Get-Date).ToString('o')
  }
  Save-JsonFile -Path $InstancesPath -Value @($filtered)
}

function Remove-InstanceRecords {
  param([string]$Profile)
  $instances = Get-RunningInstances
  $remaining = @($instances | Where-Object { $_.profile -ne $Profile })
  Save-JsonFile -Path $InstancesPath -Value @($remaining)
}

function New-LaunchEnvironment {
  param([string]$Name)
  $profileRoot = Get-ProfilePath -Name $Name
  $settings = Get-Settings

  $environment = [System.Collections.Generic.Dictionary[string,string]]::new()
  foreach ($entry in [System.Environment]::GetEnvironmentVariables().GetEnumerator()) {
    $environment[[string]$entry.Key] = [string]$entry.Value
  }

  $environment['USERPROFILE'] = $profileRoot
  $environment['HOME'] = $profileRoot
  $environment['APPDATA'] = Join-Path $profileRoot 'AppData\Roaming'
  $environment['LOCALAPPDATA'] = Join-Path $profileRoot 'AppData\Local'
  $environment['TEMP'] = Join-Path $profileRoot 'Temp'
  $environment['TMP'] = Join-Path $profileRoot 'Temp'
  $environment['MULTIGRAVITY_PROFILE'] = $Name

  if ($settings.passCredentialEnv) {
    $credential = Get-ProfileCredential -Name $Name
    if ($credential) {
      $environment['ANTIGRAVITY_USERNAME'] = $credential.UserName
      $environment['ANTIGRAVITY_PASSWORD'] = $credential.GetNetworkCredential().Password
    }
  }

  return $environment
}

function Start-Antigravity {
  param(
    [string]$Name,
    [switch]$Switch,
    [string[]]$ExtraArguments
  )
  $profile = Get-ProfileMetadata -Name $Name
  Ensure-ProfileStructure -Name $Name

  if ($Switch -and (Switch-ToProfile -Name $Name -SilentlyLaunch:$false)) {
    return
  }

  $exePath = if ($profile.appPathOverride) { $profile.appPathOverride } else { Resolve-AntigravityPath }
  if (-not (Test-Path $exePath)) {
    Fail "Antigravity executable not found at '$exePath'."
  }

  Write-UserFiles -Name $Name
  $settings = Get-Settings
  $arguments = [System.Collections.Generic.List[string]]::new()
  foreach ($item in @($settings.defaultArguments)) { [void]$arguments.Add([string]$item) }
  [void]$arguments.Add("--user-data-dir=""$(Join-Path (Get-ProfilePath -Name $Name) 'UserData')""")
  [void]$arguments.Add("--extensions-dir=""$(Join-Path (Get-ProfilePath -Name $Name) 'Extensions')""")
  foreach ($item in @($ExtraArguments)) { [void]$arguments.Add($item) }

  $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = $exePath
  $startInfo.Arguments = [string]::Join(' ', $arguments)
  $startInfo.UseShellExecute = $false
  $startInfo.WorkingDirectory = Split-Path -Path $exePath -Parent

  $environment = New-LaunchEnvironment -Name $Name
  foreach ($pair in $environment.GetEnumerator()) {
    $startInfo.Environment[$pair.Key] = $pair.Value
  }

  $process = [System.Diagnostics.Process]::Start($startInfo)
  if (-not $process) {
    Fail "Failed to launch Antigravity for profile '$Name'."
  }

  Save-InstanceRecord -Profile $Name -Pid $process.Id
  Write-Log -Level 'info' -Message "Launched profile '$Name' with PID $($process.Id)."
  Write-Host "Launched profile '$Name' (PID $($process.Id))."
}

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class Win32Window {
  [DllImport("user32.dll")]
  public static extern bool SetForegroundWindow(IntPtr hWnd);

  [DllImport("user32.dll")]
  public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
}
"@

function Switch-ToProfile {
  param(
    [string]$Name,
    [switch]$SilentlyLaunch = $true
  )
  $instances = Get-RunningInstances | Where-Object { $_.profile -eq $Name }
  foreach ($instance in $instances) {
    try {
      $process = Get-Process -Id ([int]$instance.pid) -ErrorAction Stop
      if ($process.MainWindowHandle -ne 0) {
        [void][Win32Window]::ShowWindowAsync($process.MainWindowHandle, 9)
        [void][Win32Window]::SetForegroundWindow($process.MainWindowHandle)
        Write-Host "Activated profile '$Name' (PID $($process.Id))."
        return $true
      }
    } catch {
      Write-Log -Level 'warning' -Message "Could not activate PID $($instance.pid) for profile '$Name'."
    }
  }

  if ($SilentlyLaunch) {
    Start-Antigravity -Name $Name
    return $true
  }

  return $false
}

function Set-AntigravityPath {
  param([string]$Path)
  $settings = Get-Settings
  $settings.antigravityPath = Resolve-AntigravityExecutablePath -Path $Path
  Save-Settings -Settings $settings
  Write-Host "Configured Antigravity executable: $($settings.antigravityPath)"
}

function Set-DefaultArguments {
  param([string[]]$Arguments)
  $settings = Get-Settings
  $settings.defaultArguments = @($Arguments)
  Save-Settings -Settings $settings
  Write-Host 'Updated default launch arguments.'
}

function Set-CredentialEnvMode {
  param([bool]$Enabled)
  $settings = Get-Settings
  $settings.passCredentialEnv = $Enabled
  Save-Settings -Settings $settings
  Write-Host "Credential environment pass-through: $Enabled"
}

function Show-Doctor {
  Initialize-Storage
  $path = $null
  try { $path = Resolve-AntigravityPath } catch { $path = '(not configured)' }
  $profileNames = @(Get-ProfileNames)
  $runningInstances = @(Get-RunningInstances)
  Write-Host "Data root: $DataRoot"
  Write-Host "Profiles: $($profileNames.Count)"
  Write-Host "Antigravity path: $path"
  Write-Host "Running instances: $($runningInstances.Count)"
  Write-Host "Log file: $(Join-Path $LogsRoot 'multigravity.log')"
}

function New-Shortcut {
  param(
    [string]$Name,
    [string]$Hotkey
  )
  [void](Get-ProfileMetadata -Name $Name)
  $startMenuRoot = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Multigravity'
  Ensure-Directory $startMenuRoot

  $shortcutPath = Join-Path $startMenuRoot "$Name.lnk"
  $targetPath = Join-Path $PSScriptRoot 'multigravity.cmd'

  $shell = New-Object -ComObject WScript.Shell
  $shortcut = $shell.CreateShortcut($shortcutPath)
  $shortcut.TargetPath = $targetPath
  $shortcut.Arguments = "launch $Name"
  $shortcut.WorkingDirectory = $PSScriptRoot
  $shortcut.IconLocation = "$targetPath,0"
  if ($Hotkey) {
    $shortcut.Hotkey = $Hotkey
  }
  $shortcut.Save()

  Write-Host "Created shortcut: $shortcutPath"
}

function Remove-Shortcut {
  param(
    [string]$Name,
    [switch]$Quiet
  )
  $shortcutPath = Join-Path (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Multigravity') "$Name.lnk"
  if (Test-Path $shortcutPath) {
    Remove-Item -Path $shortcutPath -Force
    if (-not $Quiet) {
      Write-Host "Removed shortcut: $shortcutPath"
    }
  }
}

function Start-Tray {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing

  $icon = New-Object System.Windows.Forms.NotifyIcon
  $icon.Text = 'Multigravity'
  $icon.Icon = [System.Drawing.SystemIcons]::Application
  $icon.Visible = $true

  $contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

  $refreshMenu = {
    $contextMenu.Items.Clear()
    foreach ($profileName in Get-ProfileNames) {
      $item = New-Object System.Windows.Forms.ToolStripMenuItem
      $item.Text = $profileName
      $item.Add_Click({
        try {
          Switch-ToProfile -Name $this.Text | Out-Null
        } catch {
          [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Multigravity')
        }
      })
      [void]$contextMenu.Items.Add($item)
    }

    if ($contextMenu.Items.Count -gt 0) {
      [void]$contextMenu.Items.Add('-')
    }

    $manage = New-Object System.Windows.Forms.ToolStripMenuItem
    $manage.Text = 'Open Data Folder'
    $manage.Add_Click({ Invoke-Item $DataRoot })
    [void]$contextMenu.Items.Add($manage)

    $exitItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $exitItem.Text = 'Exit Tray'
    $exitItem.Add_Click({
      $icon.Visible = $false
      $timer.Stop()
      [System.Windows.Forms.Application]::Exit()
    })
    [void]$contextMenu.Items.Add($exitItem)
  }

  & $refreshMenu
  $icon.ContextMenuStrip = $contextMenu

  $timer = New-Object System.Windows.Forms.Timer
  $timer.Interval = 5000
  $timer.Add_Tick($refreshMenu)
  $timer.Start()

  $icon.Add_DoubleClick({
    try {
      foreach ($profileName in Get-ProfileNames) {
        if (Switch-ToProfile -Name $profileName -SilentlyLaunch:$false) {
          break
        }
      }
    } catch {
      [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Multigravity')
    }
  })

  [System.Windows.Forms.Application]::Run()
}

function Ensure-WinFormsAssemblies {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  Add-Type -AssemblyName Microsoft.VisualBasic
}

function Select-AntigravityExecutable {
  Ensure-WinFormsAssemblies
  $dialog = New-Object System.Windows.Forms.OpenFileDialog
  $dialog.Title = 'Select Antigravity.exe'
  $dialog.Filter = 'Antigravity executable|Antigravity.exe|Executable files|*.exe|All files|*.*'
  $dialog.CheckFileExists = $true
  $dialog.Multiselect = $false
  if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    Set-AntigravityPath -Path $dialog.FileName
    return $dialog.FileName
  }
  return $null
}

function Prompt-NewProfileName {
  Ensure-WinFormsAssemblies
  return [Microsoft.VisualBasic.Interaction]::InputBox(
    'Enter a new profile name. Use letters, numbers, and hyphens only.',
    'New Profile',
    ''
  )
}

function Get-SystemDarkMode {
  try {
    $path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    $value = Get-ItemProperty -Path $path -Name 'AppsUseLightTheme' -ErrorAction Stop
    return $value.AppsUseLightTheme -eq 0
  } catch {
    return $false
  }
}

$LightTheme = @{
  FormBg = [System.Drawing.Color]::FromArgb(255, 255, 255)
  PanelBg = [System.Drawing.Color]::FromArgb(240, 240, 240)
  TextPrimary = [System.Drawing.Color]::FromArgb(0, 0, 0)
  TextSecondary = [System.Drawing.Color]::FromArgb(102, 102, 102)
  Accent = [System.Drawing.Color]::FromArgb(0, 120, 212)
  Border = [System.Drawing.Color]::FromArgb(204, 204, 204)
  SelectedBg = [System.Drawing.Color]::FromArgb(229, 243, 255)
  ButtonBg = [System.Drawing.Color]::FromArgb(245, 245, 245)
  ButtonHoverBg = [System.Drawing.Color]::FromArgb(230, 230, 230)
  ListViewBg = [System.Drawing.Color]::FromArgb(255, 255, 255)
  StatusRunning = [System.Drawing.Color]::FromArgb(16, 124, 16)
  StatusStopped = [System.Drawing.Color]::FromArgb(136, 136, 136)
  SearchBoxBg = [System.Drawing.Color]::FromArgb(255, 255, 255)
  SearchBoxBorder = [System.Drawing.Color]::FromArgb(180, 180, 180)
}

$DarkTheme = @{
  FormBg = [System.Drawing.Color]::FromArgb(30, 30, 30)
  PanelBg = [System.Drawing.Color]::FromArgb(37, 37, 37)
  TextPrimary = [System.Drawing.Color]::FromArgb(204, 204, 204)
  TextSecondary = [System.Drawing.Color]::FromArgb(157, 157, 157)
  Accent = [System.Drawing.Color]::FromArgb(0, 120, 212)
  Border = [System.Drawing.Color]::FromArgb(60, 60, 60)
  SelectedBg = [System.Drawing.Color]::FromArgb(9, 71, 113)
  ButtonBg = [System.Drawing.Color]::FromArgb(50, 50, 50)
  ButtonHoverBg = [System.Drawing.Color]::FromArgb(65, 65, 65)
  ListViewBg = [System.Drawing.Color]::FromArgb(30, 30, 30)
  StatusRunning = [System.Drawing.Color]::FromArgb(108, 203, 95)
  StatusStopped = [System.Drawing.Color]::FromArgb(128, 128, 128)
  SearchBoxBg = [System.Drawing.Color]::FromArgb(50, 50, 50)
  SearchBoxBorder = [System.Drawing.Color]::FromArgb(80, 80, 80)
}

function Apply-Theme {
  param(
    [System.Windows.Forms.Form]$Form,
    [hashtable]$Theme
  )
  $Form.BackColor = $Theme.FormBg

  foreach ($control in $Form.Controls) {
    if ($control -is [System.Windows.Forms.Label]) {
      if ($control.Name -eq 'titleLabel') {
        $control.ForeColor = $Theme.TextPrimary
      } else {
        $control.ForeColor = $Theme.TextSecondary
      }
    }
    elseif ($control -is [System.Windows.Forms.TextBox]) {
      $control.BackColor = $Theme.SearchBoxBg
      $control.ForeColor = $Theme.TextPrimary
    }
    elseif ($control -is [System.Windows.Forms.Button]) {
      $control.BackColor = $Theme.ButtonBg
      $control.ForeColor = $Theme.TextPrimary
      $control.FlatAppearance.BorderColor = $Theme.Border
    }
    elseif ($control -is [System.Windows.Forms.CheckBox]) {
      $control.ForeColor = $Theme.TextPrimary
    }
    elseif ($control -is [System.Windows.Forms.ListView]) {
      $control.BackColor = $Theme.ListViewBg
      $control.ForeColor = $Theme.TextPrimary
      $control.BackColor = $Theme.ListViewBg
    }
  }
}

function Show-ProfileToast {
  param(
    [string]$Title,
    [string]$Message,
    [string]$ProfileName
  )
  Ensure-WinFormsAssemblies
  
  $notifyIcon = New-Object System.Windows.Forms.NotifyIcon
  $notifyIcon.Visible = $false
  $notifyIcon.Icon = [System.Drawing.SystemIcons]::Application
  $notifyIcon.BalloonTipTitle = $Title
  $notifyIcon.BalloonTipText = "$Message - $ProfileName"
  $notifyIcon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
  $notifyIcon.ShowBalloonTip(3000)
  
  Start-Sleep -Milliseconds 3200
  $notifyIcon.Dispose()
}

function Show-ErrorToast {
  param(
    [string]$Title,
    [string]$Message
  )
  Ensure-WinFormsAssemblies
  
  $notifyIcon = New-Object System.Windows.Forms.NotifyIcon
  $notifyIcon.Visible = $false
  $notifyIcon.Icon = [System.Drawing.SystemIcons]::Error
  $notifyIcon.BalloonTipTitle = $Title
  $notifyIcon.BalloonTipText = $Message
  $notifyIcon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Error
  $notifyIcon.ShowBalloonTip(5000)
  
  Start-Sleep -Milliseconds 5200
  $notifyIcon.Dispose()
}

function Start-Ui {
  Ensure-WinFormsAssemblies

  $isDarkMode = Get-SystemDarkMode
  $currentTheme = if ($isDarkMode) { 'dark' } else { 'light' }

  $form = New-Object System.Windows.Forms.Form
  $form.Text = 'Multigravity'
  $form.Width = 620
  $form.Height = 480
  $form.StartPosition = 'CenterScreen'
  $form.FormBorderStyle = 'FixedDialog'
  $form.MaximizeBox = $false
  $form.MinimizeBox = $true
  $form.KeyPreview = $true

  $titleLabel = New-Object System.Windows.Forms.Label
  $titleLabel.Name = 'titleLabel'
  $titleLabel.Text = 'Antigravity profiles'
  $titleLabel.AutoSize = $true
  $titleLabel.Font = New-Object System.Drawing.Font('Segoe UI', 13, [System.Drawing.FontStyle]::Bold)
  $titleLabel.Location = New-Object System.Drawing.Point(16, 14)
  $form.Controls.Add($titleLabel)

  $themeToggle = New-Object System.Windows.Forms.CheckBox
  $themeToggle.Name = 'themeToggle'
  $themeToggle.Text = if ($isDarkMode) { 'Dark' } else { 'Light' }
  $themeToggle.AutoSize = $true
  $themeToggle.Location = New-Object System.Drawing.Point(520, 14)
  $themeToggle.Checked = $isDarkMode
  $themeToggle.Add_CheckedChanged({
    if ($themeToggle.Checked) {
      $script:currentTheme = 'dark'
      Apply-Theme -Form $form -Theme $DarkTheme
      $themeToggle.Text = 'Dark'
    } else {
      $script:currentTheme = 'light'
      Apply-Theme -Form $form -Theme $LightTheme
      $themeToggle.Text = 'Light'
    }
  })
  $form.Controls.Add($themeToggle)

  $pathLabel = New-Object System.Windows.Forms.Label
  $pathLabel.Name = 'pathLabel'
  $pathLabel.AutoSize = $false
  $pathLabel.Width = 360
  $pathLabel.Height = 34
  $pathLabel.Location = New-Object System.Drawing.Point(16, 44)
  $form.Controls.Add($pathLabel)

  $setPathButton = New-Object System.Windows.Forms.Button
  $setPathButton.Text = 'Locate App'
  $setPathButton.Width = 100
  $setPathButton.Height = 28
  $setPathButton.Location = New-Object System.Drawing.Point(390, 44)
  $setPathButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $setPathButton.FlatAppearance.BorderSize = 1
  $form.Controls.Add($setPathButton)

  $searchBox = New-Object System.Windows.Forms.TextBox
  $searchBox.Name = 'searchBox'
  $searchBox.PlaceholderText = 'Search profiles...'
  $searchBox.Width = 588
  $searchBox.Height = 24
  $searchBox.Location = New-Object System.Drawing.Point(16, 76)
  $searchBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
  $searchBox.Add_TextChanged({
    $filter = $searchBox.Text.Trim()
    foreach ($item in $profilesView.Items) {
      if ($filter -eq '' -or $item.Text -like "*$filter*") {
        $item.BackColor = [System.Drawing.Color]::Transparent
      }
    }
  })
  $form.Controls.Add($searchBox)

  $profilesView = New-Object System.Windows.Forms.ListView
  $profilesView.Name = 'profilesView'
  $profilesView.View = [System.Windows.Forms.View]::Details
  $profilesView.FullRowSelect = $true
  $profilesView.MultiSelect = $false
  $profilesView.HideSelection = $false
  $profilesView.Width = 588
  $profilesView.Height = 230
  $profilesView.Location = New-Object System.Drawing.Point(16, 106)
  $profilesView.SmallImageList = New-Object System.Windows.Forms.ImageList
  $profilesView.SmallImageList.Images.Add('running', (New-Object System.Drawing.Bitmap(16, 16)))
  $profilesView.SmallImageList.Images.Add('stopped', (New-Object System.Drawing.Bitmap(16, 16)))
  [void]$profilesView.Columns.Add('Profile', 180)
  [void]$profilesView.Columns.Add('Status', 80)
  [void]$profilesView.Columns.Add('Theme', 120)
  [void]$profilesView.Columns.Add('Creds', 60)
  $form.Controls.Add($profilesView)

  $contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
  $contextMenu.Items.Add('Open', $null, { & $openSelectedProfile })
  $contextMenu.Items.Add('Switch To', $null, { & $switchSelectedProfile })
  $contextMenu.Items.Add('-')
  $contextMenu.Items.Add('Delete', $null, { & $deleteSelectedProfile })
  $profilesView.ContextMenuStrip = $contextMenu

  $launchButton = New-Object System.Windows.Forms.Button
  $launchButton.Text = 'Open'
  $launchButton.Width = 85
  $launchButton.Location = New-Object System.Drawing.Point(16, 350)
  $launchButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $launchButton.FlatAppearance.BorderSize = 1
  $form.Controls.Add($launchButton)

  $switchButton = New-Object System.Windows.Forms.Button
  $switchButton.Text = 'Switch'
  $switchButton.Width = 85
  $switchButton.Location = New-Object System.Drawing.Point(111, 350)
  $switchButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $switchButton.FlatAppearance.BorderSize = 1
  $form.Controls.Add($switchButton)

  $newButton = New-Object System.Windows.Forms.Button
  $newButton.Text = 'New'
  $newButton.Width = 85
  $newButton.Location = New-Object System.Drawing.Point(206, 350)
  $newButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $newButton.FlatAppearance.BorderSize = 1
  $form.Controls.Add($newButton)

  $deleteButton = New-Object System.Windows.Forms.Button
  $deleteButton.Text = 'Delete'
  $deleteButton.Width = 85
  $deleteButton.Location = New-Object System.Drawing.Point(301, 350)
  $deleteButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $deleteButton.FlatAppearance.BorderSize = 1
  $form.Controls.Add($deleteButton)

  $credentialButton = New-Object System.Windows.Forms.Button
  $credentialButton.Text = 'Save Login'
  $credentialButton.Width = 95
  $credentialButton.Location = New-Object System.Drawing.Point(396, 350)
  $credentialButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $credentialButton.FlatAppearance.BorderSize = 1
  $form.Controls.Add($credentialButton)

  $footerLabel = New-Object System.Windows.Forms.Label
  $footerLabel.Name = 'footerLabel'
  $footerLabel.Text = 'Double-click or press Enter to open. Ctrl+N for new profile.'
  $footerLabel.AutoSize = $true
  $footerLabel.Location = New-Object System.Drawing.Point(16, 388)
  $form.Controls.Add($footerLabel)

  $showStatus = {
    param([string]$Message)
    $footerLabel.Text = $Message
  }

  $updatePathLabel = {
    try {
      $path = Resolve-AntigravityPath
      $pathLabel.Text = "Using: $path"
    } catch {
      $pathLabel.Text = 'Antigravity.exe not configured yet.'
    }
  }

  $getSelectedProfileName = {
    if ($profilesView.SelectedItems.Count -eq 0) {
      [System.Windows.Forms.MessageBox]::Show('Select a profile first.', 'Multigravity') | Out-Null
      return $null
    }
    return $profilesView.SelectedItems[0].Text
  }

  $updateActionButtons = {
    $state = Get-UiActionState -ProfileCount $profilesView.Items.Count -SelectedCount $profilesView.SelectedItems.Count
    $launchButton.Enabled = $state.LaunchEnabled
    $switchButton.Enabled = $state.SwitchEnabled
    $deleteButton.Enabled = $state.DeleteEnabled
    $credentialButton.Enabled = $state.SaveLoginEnabled
    & $showStatus $state.StatusMessage
  }

  $refreshProfiles = {
    $profilesView.Items.Clear()
    $filter = $searchBox.Text.Trim()
    foreach ($summary in @(Get-ProfileSummaries)) {
      if ($filter -ne '' -and $summary.Name -notlike "*$filter*") {
        continue
      }
      $item = New-Object System.Windows.Forms.ListViewItem($summary.Name)
      $item.ImageKey = if ($summary.Status -eq 'Running') { 'running' } else { 'stopped' }
      $credText = if ($summary.HasCredentials) { 'Yes' } else { 'No' }
      [void]$item.SubItems.Add($summary.Status)
      [void]$item.SubItems.Add($summary.Theme)
      [void]$item.SubItems.Add($credText)
      [void]$profilesView.Items.Add($item)
    }

    if ($profilesView.Items.Count -gt 0) {
      $profilesView.Items[0].Selected = $true
      $profilesView.Select()
    }

    & $updatePathLabel
    & $updateActionButtons
  }

  $deleteSelectedProfile = {
    $selected = & $getSelectedProfileName
    if (-not $selected) { return }
    $result = [System.Windows.Forms.MessageBox]::Show(
      "Delete profile '$selected' and its data?",
      'Multigravity',
      [System.Windows.Forms.MessageBoxButtons]::YesNo,
      [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($result -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    try {
      Remove-Profile -Name $selected -Force
      & $refreshProfiles
      & $showStatus "Deleted $selected"
      Show-ProfileToast -Title 'Profile Deleted' -Message 'Deleted profile' -ProfileName $selected
    } catch {
      [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Multigravity') | Out-Null
      & $showStatus $_.Exception.Message
      Show-ErrorToast -Title 'Error' -Message $_.Exception.Message
    }
  }

  $createNewProfile = {
    $name = Prompt-NewProfileName
    if ([string]::IsNullOrWhiteSpace($name)) { return }
    try {
      New-Profile -Name $name.Trim() -Theme $null -FontSize 0 -Keybindings $null -Extensions @()
      & $refreshProfiles
      & $showStatus "Created $name"
      Show-ProfileToast -Title 'Profile Created' -Message 'New profile created' -ProfileName $name
    } catch {
      [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Multigravity') | Out-Null
      & $showStatus $_.Exception.Message
      Show-ErrorToast -Title 'Error' -Message $_.Exception.Message
    }
  }

  $openSelectedProfile = {
    $selected = & $getSelectedProfileName
    if (-not $selected) { return }
    try {
      & $showStatus "Launching $selected..."
      Start-Antigravity -Name $selected -Switch
      & $refreshProfiles
      & $showStatus "Opened $selected"
      Show-ProfileToast -Title 'Profile Opened' -Message 'Launching profile' -ProfileName $selected
    } catch {
      [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Multigravity') | Out-Null
      & $showStatus $_.Exception.Message
      Show-ErrorToast -Title 'Launch Failed' -Message $_.Exception.Message
    }
  }

  $switchSelectedProfile = {
    $selected = & $getSelectedProfileName
    if (-not $selected) { return }
    try {
      Switch-ToProfile -Name $selected | Out-Null
      & $refreshProfiles
      & $showStatus "Switched to $selected"
      Show-ProfileToast -Title 'Profile Switched' -Message 'Switched to profile' -ProfileName $selected
    } catch {
      [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Multigravity') | Out-Null
      & $showStatus $_.Exception.Message
      Show-ErrorToast -Title 'Switch Failed' -Message $_.Exception.Message
    }
  }

  $launchButton.Add_Click($openSelectedProfile)
  $switchButton.Add_Click($switchSelectedProfile)
  $profilesView.Add_DoubleClick($openSelectedProfile)

  $setPathButton.Add_Click({
    try {
      $selectedPath = Select-AntigravityExecutable
      if ($selectedPath) {
        & $updatePathLabel
        & $showStatus 'Updated Antigravity.exe path.'
        if ($profilesView.Items.Count -eq 0) {
          $result = [System.Windows.Forms.MessageBox]::Show(
            'No profiles exist yet. Create your first profile now?',
            'Multigravity',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
          )
          if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            & $createNewProfile
          }
        }
      }
    } catch {
      [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Multigravity') | Out-Null
      & $showStatus $_.Exception.Message
    }
  })

  $newButton.Add_Click($createNewProfile)
  $deleteButton.Add_Click($deleteSelectedProfile)

  $credentialButton.Add_Click({
    $selected = & $getSelectedProfileName
    if (-not $selected) { return }

    $result = [System.Windows.Forms.MessageBox]::Show(
      "Store or replace encrypted credentials for '$selected'?",
      'Multigravity',
      [System.Windows.Forms.MessageBoxButtons]::YesNo,
      [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($result -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    try {
      Set-ProfileCredential -Name $selected
      & $refreshProfiles
      & $showStatus "Updated credentials for $selected"
      Show-ProfileToast -Title 'Credentials Saved' -Message 'Encrypted credentials stored' -ProfileName $selected
    } catch {
      [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Multigravity') | Out-Null
      & $showStatus $_.Exception.Message
      Show-ErrorToast -Title 'Error' -Message $_.Exception.Message
    }
  })

  $profilesView.Add_SelectedIndexChanged($updateActionButtons)

  $form.Add_KeyDown({
    param($sender, $e)
    if ($e.KeyCode -eq 'Enter') {
      & $openSelectedProfile
      $e.SuppressKeyPress = $true
    }
    elseif ($e.KeyCode -eq 'Delete' -and $profilesView.SelectedItems.Count -gt 0) {
      & $deleteSelectedProfile
      $e.SuppressKeyPress = $true
    }
    elseif ($e.KeyCode -eq 'N' -and $e.Control) {
      & $createNewProfile
      $e.SuppressKeyPress = $true
    }
    elseif ($e.KeyCode -eq 'Escape') {
      $form.Close()
    }
    elseif ($e.KeyCode -eq 'F' -and $e.Control) {
      $searchBox.Focus()
      $e.SuppressKeyPress = $true
    }
  })

  $searchBox.Add_KeyDown({
    param($sender, $e)
    if ($e.KeyCode -eq 'Escape') {
      $searchBox.Text = ''
      $profilesView.Focus()
      $e.SuppressKeyPress = $true
    }
    elseif ($e.KeyCode -eq 'Down' -and $profilesView.Items.Count -gt 0) {
      $profilesView.Items[0].Selected = $true
      $profilesView.Focus()
      $e.SuppressKeyPress = $true
    }
  })

  $form.Add_Shown({
    if ($isDarkMode) {
      Apply-Theme -Form $form -Theme $DarkTheme
    } else {
      Apply-Theme -Form $form -Theme $LightTheme
    }
    & $refreshProfiles
  })
  [void]$form.ShowDialog()
}

function Show-Usage {
  @'
Usage: multigravity <command> [arguments]

Commands:
  ui                                     Open the minimal profile window
  config set-app <path>                  Set Antigravity.exe path
  config set-args [args...]              Set default launch arguments
  config credential-env on|off           Pass stored credentials as env vars
  profile new <name> [options]           Create a profile
  profile set <name> [options]           Update profile settings metadata
  profile list                           List profiles
  profile rename <old> <new>             Rename a profile
  profile delete <name> [-Force]         Delete a profile
  credential set <name>                  Store encrypted credentials
  credential clear <name>                Remove stored credentials
  launch <name> [extra args...]          Launch a profile
  switch <name>                          Activate running window or launch
  shortcut create <name> [hotkey]        Create a Start Menu shortcut
  tray                                   Run the system tray switcher
  doctor                                 Show diagnostics
  help                                   Show this help

Profile options:
  --theme <name> --font-size <int> --keybindings <name> --extensions ext1,ext2
'@ | Write-Host
}

function Split-Extensions {
  param([string]$Value)
  if (-not $Value) { return @() }
  return @($Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Get-OptionValue {
  param(
    [string[]]$Tokens,
    [string]$Name
  )
  $prefix = "--$Name="
  foreach ($token in $Tokens) {
    if ($token -like "$prefix*") {
      return $token.Substring($prefix.Length)
    }
  }
  return $null
}

function Has-Option {
  param(
    [string[]]$Tokens,
    [string]$Name
  )
  $prefix = "--$Name="
  return [bool](Get-OptionValue -Tokens $Tokens -Name $Name)
}

try {
  Initialize-Storage

  if (-not $Args -or $Args.Count -eq 0) {
    Start-Ui
    exit 0
  }

  switch ($Args[0]) {
    'help' { Show-Usage }
    'doctor' { Show-Doctor }
    'ui' { Start-Ui }
    'tray' { Start-Tray }
    'config' {
      switch ($Args[1]) {
        'set-app' { Set-AntigravityPath -Path $Args[2] }
        'set-args' {
          if ($Args.Count -lt 3) { Set-DefaultArguments -Arguments @() } else { Set-DefaultArguments -Arguments $Args[2..($Args.Count - 1)] }
        }
        'credential-env' {
          if ($Args[2] -eq 'on') { Set-CredentialEnvMode -Enabled $true }
          elseif ($Args[2] -eq 'off') { Set-CredentialEnvMode -Enabled $false }
          else { Fail "Use 'on' or 'off'." }
        }
        default { Fail 'Unknown config command.' }
      }
    }
    'profile' {
      switch ($Args[1]) {
        'new' {
          $extensions = Split-Extensions -Value (Get-OptionValue -Tokens $Args -Name 'extensions')
          $theme = Get-OptionValue -Tokens $Args -Name 'theme'
          $fontRaw = Get-OptionValue -Tokens $Args -Name 'font-size'
          $keybindings = Get-OptionValue -Tokens $Args -Name 'keybindings'
          $fontSize = if ($fontRaw) { [int]$fontRaw } else { 0 }
          New-Profile -Name $Args[2] -Theme $theme -FontSize $fontSize -Keybindings $keybindings -Extensions $extensions
        }
        'set' {
          $setParams = @{ Name = $Args[2] }
          if (Has-Option -Tokens $Args -Name 'theme') {
            $setParams.Theme = Get-OptionValue -Tokens $Args -Name 'theme'
          }
          if (Has-Option -Tokens $Args -Name 'font-size') {
            $setParams.FontSize = [int](Get-OptionValue -Tokens $Args -Name 'font-size')
          }
          if (Has-Option -Tokens $Args -Name 'keybindings') {
            $setParams.Keybindings = Get-OptionValue -Tokens $Args -Name 'keybindings'
          }
          if (Has-Option -Tokens $Args -Name 'extensions') {
            $setParams.Extensions = Split-Extensions -Value (Get-OptionValue -Tokens $Args -Name 'extensions')
          }
          Set-Profile @setParams
        }
        'list' { List-Profiles }
        'rename' { Rename-Profile -OldName $Args[2] -NewName $Args[3] }
        'delete' { Remove-Profile -Name $Args[2] -Force:($Args -contains '-Force') }
        default { Fail 'Unknown profile command.' }
      }
    }
    'credential' {
      switch ($Args[1]) {
        'set' { Set-ProfileCredential -Name $Args[2] }
        'clear' { Clear-ProfileCredential -Name $Args[2] }
        default { Fail 'Unknown credential command.' }
      }
    }
    'launch' {
      if ($Args.Count -lt 2) { Fail 'Profile name is required.' }
      $extra = if ($Args.Count -gt 2) { $Args[2..($Args.Count - 1)] } else { @() }
      Start-Antigravity -Name $Args[1] -ExtraArguments $extra
    }
    'switch' { Switch-ToProfile -Name $Args[1] | Out-Null }
    'shortcut' {
      if ($Args[1] -ne 'create') { Fail 'Unknown shortcut command.' }
      $hotkey = if ($Args.Count -gt 3) { $Args[3] } else { $null }
      New-Shortcut -Name $Args[2] -Hotkey $hotkey
    }
    default {
      Start-Antigravity -Name $Args[0] -Switch
    }
  }
} catch {
  Write-Error $_.Exception.Message
  exit 1
}
