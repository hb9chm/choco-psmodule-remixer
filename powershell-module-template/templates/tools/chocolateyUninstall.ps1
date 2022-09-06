$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -parent $MyInvocation.MyCommand.Definition
$moduleName = '[[ModuleName]]'  # this may be different from the package name and different case
$moduleVersion = '[[PackageVersion]]'
$savedParamsPath = Join-Path $toolsDir -ChildPath 'parameters.saved'

if (Test-Path -Path $savedParamsPath) {
    $removePath = Get-Content -Path $savedParamsPath
}
else {
    $removePath = Join-Path -Path $env:ProgramFiles -ChildPath "WindowsPowerShell\Modules\$moduleName\$moduleVersion"
    $removePath += Join-Path -Path $env:ProgramFiles -ChildPath "PowerShell\Modules\$moduleName\$moduleVersion"
}

ForEach ($path in $removePath) {
    Write-Verbose "Removing all version of '$moduleName' from '$path'."
    Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
}
