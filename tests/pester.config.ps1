# Pester 5.x Configuration
# Run with: pwsh -Command "Invoke-Pester"

$config = New-PesterConfiguration
$config.Run.Path = '.\tests\*.Tests.ps1'
$config.Output.Verbosity = 'Detailed'
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = '.\multigravity.core.psm1'
$config.CodeCoverage.OutputPath = '.\coverage.xml'
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = '.\test-results.xml'
$config.TestResult.OutputFormat = 'NUnitXml'
$config
