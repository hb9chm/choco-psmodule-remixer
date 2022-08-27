﻿#Requires -Version 5.0
#Requires -Modules @{ ModuleName="PowershellGet"; ModuleVersion="3.0.0" }

Function Invoke-DownloadPSModulePkg {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'String needs to be in plain text when used for header')]
    param (
        [string]$downloadXML,
        [string]$configXML,
        [string]$folderXML,
        [switch]$Force
    )
    $ErrorActionPreference = 'Stop'

    Try {
        . Get-RemixerConfig -upperFunctionBoundParameters $PSBoundParameters
    } Catch {
        Write-Error "Error details:`n$($PSItem.ToString())`n$($PSItem.InvocationInfo.Line)`n$($PSItem.ScriptStackTrace)"
    }

    if ($PSBoundParameters['downloadXML']) {
        $downloadXML = (Resolve-Path $downloadXML).path
    } elseif ($upperFunctionBoundParameters['folderxml']) {
        $downloadXML = Join-Path $folderXML 'download.xml'
    } else {
        Write-Verbose "Falling back to checking next to module for download.xml"
        $downloadXML = Join-Path (Split-Path $PSScriptRoot) 'download.xml'

        If (!(Test-Path $downloadXML)) {
            Write-Verbose "Falling back to checking one level up for download.xml"
            $downloadXML = Join-Path (Split-Path (Split-Path $PSScriptRoot)) 'download.xml'
        }

        If (!(Test-Path $downloadXML)) {
            Write-Verbose "Falling back to checking in appdata for download.xml"
            $downloadXML = Join-Path $profilePath 'download.xml'
        }
    }

    $parameters = @{
        Name    = "ChocolateyCommunityPackageRepository"
        Uri     = "https://community.chocolatey.org/api/v2"
        Trusted = $true
    }
    Unregister-PSResourceRepository -Name PSGallery -ErrorAction SilentlyContinue
    Get-PSResourceRepository | Where-Object { $_.Uri -eq $parameters.Uri } | Unregister-PSResourceRepository -ErrorAction SilentlyContinue
    Register-PSResourceRepository @parameters -ErrorAction SilentlyContinue
    # Make sure that PSGallery is registered
    Register-PSResourceRepository -PSGallery -ErrorAction SilentlyContinue -Trusted

    [XML]$downloadXMLcontent = Get-Content $downloadXML

    $downloadXMLcontent.SelectNodes("//pspkg") | ForEach-Object {
        If (-not ([string]::IsNullOrEmpty($_.version))) {
            $pkg = Find-PSResource -Name $_.id -Version $_.version -Repository PSGallery
            $version = (New-Object -TypeName NuGet.Versioning.NuGetVersion -ArgumentList $pkg.Version)
            $normalizedVersion = $version.ToNormalizedString()
            $nupkgFileName = "$($pkg.Name).$normalizedVersion.nupkg"
            if (($Force) -or (-not (Test-Path -LiteralPath (Join-Path $config.SearchPSModuleDir $nupkgFileName )))) {
                Write-Verbose "Downloading powershell module package $($_.id) version $($_.version) to $($config.searchPSModuleDir)"
                $pkg | Save-PSResource -Path $config.SearchPSModuleDir -AsNupkg -ErrorAction SilentlyContinue -Quiet
            }
        } else {
            $pkg = Find-PSResource -Name $_.id -Repository PSGallery
            $version = New-Object -TypeName NuGet.Versioning.NuGetVersion -ArgumentList $pkg.Version
            $normalizedVersion = $version.ToNormalizedString()
            $nupkgFileName = "$($pkg.Name).$normalizedVersion.nupkg"
            if (($Force) -or (-not (Test-Path -LiteralPath (Join-Path $config.SearchPSModuleDir $nupkgFileName )))) {
                Write-Verbose "Downloading newest package $($_.id) to $($config.searchPSModuleDir)"
                $pkg | Save-PSResource -Path $config.SearchPSModuleDir -AsNupkg -ErrorAction SilentlyContinue -Quiet
            }
        }
    }
    return
}
