#Requires -Version 5.1

$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -parent $MyInvocation.MyCommand.Definition
$moduleName = '[[ModuleName]]' # this may be different from the package name and different case
$moduleVersion = '[[PackageVersion]]'  # this may change so keep this here
$savedParamsPath = Join-Path $toolsDir -ChildPath 'parameters.saved'

if ($PSVersionTable.PSVersion.Major -lt 5) {
    throw "$moduleName module requires a minimum of PowerShell v5.1"
}
# module may already be installed outside of Chocolatey
Remove-Module -Name $moduleName -Force -ErrorAction SilentlyContinue

# remove the saved parameters file if it exists
if (Test-Path -Path $savedParamsPath) {
    Remove-Item -Path $savedParamsPath -Force
}

$params = Get-PackageParameters

$sourcePath = Join-Path -Path $toolsDir -ChildPath "$modulename.zip"
$destinationPath = @()
if ($params.Desktop -or (-not $params.Core)) {
    $destinationPath += Join-Path -Path $env:ProgramFiles -ChildPath "WindowsPowerShell\Modules\$moduleName\$moduleVersion"
}

if ($params.Core) {
    $destinationPath += Join-Path -Path $env:ProgramFiles -ChildPath "PowerShell\Modules\$moduleName\$moduleVersion"
}

ForEach ($destPath in $destinationPath) {
    Write-Verbose "Installing '$modulename' to '$destPath'."

    # check destination path exists and create if not
    if (-not (Test-Path -Path $destPath)) {
        $null = New-Item -Path $destPath -ItemType Directory -Force
    }
    Get-ChocolateyUnzip -FileFullPath $sourcePath -Destination $destPath -PackageName $moduleName

    # save the locations where the module was installed so we can uninstall it
    Add-Content -Path $savedParamsPath -Value $destPath
}

# cleanup the module from the Chocolatey $toolsDir folder
Remove-Item -Path $sourcePath -Force -Recurse