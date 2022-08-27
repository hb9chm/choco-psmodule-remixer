$ErrorActionPreference = 'Stop'

$moduleName = '[[ModuleName]]'    # this could be different from package name
$toolsDir = Split-Path -parent $MyInvocation.MyCommand.Definition
$depModulesPath = Join-Path $toolsdir -ChildPath 'dependent.modules'

$modules = Get-Content -Path $depModulesPath
ForEach ($m in $modules) {
    Remove-Module -Name $m -Force -ErrorAction SilentlyContinue
}