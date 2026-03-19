[CmdletBinding()]
param(
  [string]$InstallRoot = "$env:LOCALAPPDATA\Programs\Multigravity"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path $InstallRoot)) {
  New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
}

$sourceRoot = $PSScriptRoot
$files = @(
  'multigravity.ps1',
  'multigravity.cmd',
  'README.md'
)

foreach ($file in $files) {
  Copy-Item -Path (Join-Path $sourceRoot $file) -Destination (Join-Path $InstallRoot $file) -Force
}

$shimDir = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
if (-not (Test-Path $shimDir)) {
  New-Item -ItemType Directory -Path $shimDir -Force | Out-Null
}

$shimPath = Join-Path $shimDir 'multigravity.cmd'
$shimContent = "@echo off`r`n""$InstallRoot\multigravity.cmd"" %*`r`n"
$shimContent | Set-Content -Path $shimPath -Encoding ASCII

Write-Host "Installed Multigravity to $InstallRoot"
Write-Host "Command shim created at $shimPath"
Write-Host "Next: multigravity config set-app ""C:\Path\To\Antigravity.exe"""
