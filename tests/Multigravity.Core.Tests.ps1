Import-Module "$PSScriptRoot\..\multigravity.core.psm1" -Force

Describe 'Resolve-AntigravityExecutablePath' {
  BeforeAll {
    $testRoot = Join-Path $TestDrive 'antigravity'
    $appDir = Join-Path $testRoot 'Programs\Antigravity'
    New-Item -ItemType Directory -Path $appDir -Force | Out-Null
    $exePath = Join-Path $appDir 'Antigravity.exe'
    Set-Content -Path $exePath -Value 'binary' -Encoding ASCII
  }

  It 'accepts a direct executable path' {
    $resolved = Resolve-AntigravityExecutablePath -Path $exePath
    $resolved | Should -Be (Resolve-Path $exePath).Path
  }

  It 'accepts the install directory and appends Antigravity.exe' {
    $resolved = Resolve-AntigravityExecutablePath -Path $appDir
    $resolved | Should -Be (Resolve-Path $exePath).Path
  }

  It 'throws when the path is blank' {
    { Resolve-AntigravityExecutablePath -Path '' } | Should -Throw 'Path is required.'
  }

  It 'throws when Antigravity.exe is missing' {
    try {
      Resolve-AntigravityExecutablePath -Path (Join-Path $testRoot 'Missing')
      throw 'Expected missing executable error.'
    } catch {
      $_.Exception.Message.StartsWith('Antigravity.exe not found:') | Should -Be $true
    }
  }
}

Describe 'Get-UiActionState' {
  It 'disables profile actions when no profiles exist' {
    $state = Get-UiActionState -ProfileCount 0 -SelectedCount 0
    $state.LaunchEnabled | Should -Be $false
    $state.SwitchEnabled | Should -Be $false
    $state.DeleteEnabled | Should -Be $false
    $state.SaveLoginEnabled | Should -Be $false
    $state.StatusMessage | Should -Be 'No profiles yet. Click New to create your first one.'
  }

  It 'keeps profile actions disabled when profiles exist but none are selected' {
    $state = Get-UiActionState -ProfileCount 2 -SelectedCount 0
    $state.LaunchEnabled | Should -Be $false
    $state.SwitchEnabled | Should -Be $false
    $state.DeleteEnabled | Should -Be $false
    $state.SaveLoginEnabled | Should -Be $false
    $state.StatusMessage | Should -Be 'Profiles: 2'
  }

  It 'enables profile actions when a profile is selected' {
    $state = Get-UiActionState -ProfileCount 2 -SelectedCount 1
    $state.LaunchEnabled | Should -Be $true
    $state.SwitchEnabled | Should -Be $true
    $state.DeleteEnabled | Should -Be $true
    $state.SaveLoginEnabled | Should -Be $true
    $state.StatusMessage | Should -Be 'Profiles: 2'
  }
}
