$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$packageRoot = Split-Path -Parent $toolsDir
$repoRoot = Split-Path -Parent $packageRoot

& (Join-Path $repoRoot 'install-windows.ps1')
if ($LASTEXITCODE -ne 0) {
  throw 'Multigravity installation failed.'
}
