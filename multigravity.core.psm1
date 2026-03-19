function Resolve-AntigravityExecutablePath {
  param([string]$Path)

  if ([string]::IsNullOrWhiteSpace($Path)) {
    throw 'Path is required.'
  }

  $resolvedPath = $Path
  if (Test-Path $Path -PathType Container) {
    $resolvedPath = Join-Path $Path 'Antigravity.exe'
  }

  if (-not (Test-Path $resolvedPath -PathType Leaf)) {
    throw "Antigravity.exe not found: $resolvedPath"
  }

  return (Resolve-Path $resolvedPath).Path
}

function Get-UiActionState {
  param(
    [int]$ProfileCount,
    [int]$SelectedCount
  )

  $hasSelection = $ProfileCount -gt 0 -and $SelectedCount -gt 0
  $statusMessage = if ($ProfileCount -eq 0) {
    'No profiles yet. Click New to create your first one.'
  } else {
    "Profiles: $ProfileCount"
  }

  return [pscustomobject]@{
    LaunchEnabled = $hasSelection
    SwitchEnabled = $hasSelection
    DeleteEnabled = $hasSelection
    SaveLoginEnabled = $hasSelection
    StatusMessage = $statusMessage
  }
}

Export-ModuleMember -Function Resolve-AntigravityExecutablePath, Get-UiActionState
