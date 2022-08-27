$moduleFile = [system.io.path]::Combine((Split-Path -Parent $PSScriptRoot), 'choco-psmodule-remixer', 'choco-psmodule-remixer.psm1')
Import-Module $moduleFile -Force
Invoke-DownloadPSModulePkg -folderXML (Split-Path -Parent $PSScriptRoot)