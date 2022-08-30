#Requires -Version 5.0
Function Invoke-InternalizePSModulePkg {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'String needs to be in plain text when used for header')]
    param (
        [string]$configXML,
        [string]$internalizedXML,
        [string]$repoCheckXML,
        [string]$folderXML,
        [string]$privateRepoCreds,
        [string]$proxyRepoCreds,
        [switch]$thoroughList,
        [switch]$skipRepoCheck,
        [switch]$skipRepoMove,
        [switch]$noSave,
        [switch]$writeVersion,
        [switch]$noPack
    )
    $ErrorActionPreference = 'Stop'


    Try {
        . Get-RemixerConfig -upperFunctionBoundParameters $PSBoundParameters
    } Catch {
        Write-Error "Error details:`n$($PSItem.ToString())`n$($PSItem.InvocationInfo.Line)`n$($PSItem.ScriptStackTrace)"
    }

    if (($config.repoMove -eq "yes") -and (!($skipRepoMove))) {
        $invokeRepoMoveArgs = @{
            proxyRepoCreds   = $proxyRepoCreds
            configXML        = $configXML
            internalizedXML  = $internalizedXML
            repoCheckXML     = $repoCheckXML
            calledInternally = $true
        }

        Try {
            Invoke-RepoMove @invokeRepoMoveArgs
        } Catch {
            Write-Error "Error details:`n$($PSItem.ToString())`n$($PSItem.InvocationInfo.Line)`n$($PSItem.ScriptStackTrace)"
        }
    }


    if (($config.repoCheck -eq "yes") -and (!($skipRepoCheck))) {
        $invokeRepoCheckArgs = @{
            privateRepoCreds = $privateRepoCreds
            configXML        = $configXML
            internalizedXML  = $internalizedXML
            repoCheckXML     = $repoCheckXML
            calledInternally = $true
        }

        Try {
            Invoke-RepoCheck @invokeRepoCheckArgs
        } Catch {
            Write-Error "Error details:`n$($PSItem.ToString())`n$($PSItem.InvocationInfo.Line)`n$($PSItem.ScriptStackTrace)"
        }
    }


    #need this as normal PWSH arrays are slow to add an element, this can add them quickly
    [System.Collections.ArrayList]$nupkgObjArray = @()

    #todo, add switch here to select from other options to get list of nupkgs
    Write-Verbose "Checking for packages in $($config.searchPSModuleDir)"
    if ($thoroughList) {
        $nupkgArray = Get-ChildItem -File $config.searchPSModuleDir -Filter "*.nupkg" -Recurse
    } else {
        #filters based on folder name, therefore less files to open later and therefore faster, but may not be useful in all circumstances.
        $nupkgArray = (Get-ChildItem -File $config.searchPSModuleDir -Filter "*.nupkg" -Recurse) | Where-Object {
            ( ($_.directory.name -notin $config.personal.id) `
                -and ($_.directory.Parent.name -notin $config.personal.id) `
            )
        }
    }


    #unique needed to workaround a bug if accessing searchDir from a samba share where things show up twice if there are directories with the same name but different case.
    $nupkgArray | Select-Object -Unique | ForEach-Object {
        $nuspecDetails = Read-NuspecVersion -NupkgPath $_.fullname
        $nuspecVersion = $nuspecDetails[0]
        $nuspecID = $nuspecDetails[1]

        #todo, make this faster, hash table? linq? other?
        [array]$internalizedVersions = ($internalizedXMLcontent.internalized.pspkg | Where-Object { $_.id -ieq "$nuspecID" }).version

        if ($internalizedVersions -icontains $nuspecVersion) {
            Write-Verbose "$nuspecID $nuspecVersion is already internalized"
        } else {
            $idDir = (Join-Path $config.workPSModuleDir $nuspecID)
            $versionDir = (Join-Path $idDir $nuspecVersion)
            $newpath = (Join-Path $versionDir $_.name)
            $toolsDir = (Join-Path $versionDir "tools")


            if ($writeVersion) {
                if ($internalizedVersions.count -ge 1) {
                    $oldVersion = $internalizedVersions | Select-Object -Last 1
                } else {
                    $oldVersion = "null"
                }
            } else {
                $oldVersion = "null"
            }

            $obj = [PSCustomObject]@{
                nupkgName  = $_.name
                origPath   = $_.fullname
                version    = $nuspecVersion
                nuspecID   = $nuspecID
                status     = $status
                idDir      = $idDir
                versionDir = $versionDir
                newPath    = $newpath
                oldVersion = $oldVersion
            }

            $nupkgObjArray.add($obj) | Out-Null

            Write-Information "Found $nuspecID $nuspecVersion to internalize" -InformationAction Continue
        }
    }


    #don't need the list anymore, use nupkgObjArray
    $nupkgArray = $null
    [system.gc]::Collect()

    Foreach ($obj in $nupkgObjArray) {
        Write-Output "Starting $($obj.nuspecID)"

        Remove-Item -Force -EA 0 -Path $obj.VersionDir -Recurse
        $null = New-Item -Path $obj.VersionDir -ItemType Directory -Force -ErrorAction SilentlyContinue

        $failed = $false
        Try {
            $startProcessArgs = @{
                FilePath         = "choco"
                ArgumentList     = "new $($obj.nuspecID)", "-t powershell-module", "-f", `
                    "ModuleName=$($obj.nuspecID)", "PackageVersion=$($obj.Version)", `
                    "--limit-output"
                WorkingDirectory = $obj.versionDir
                NoNewWindow      = $true
                Wait             = $true
                PassThru         = $true
            }

            $newcode = Start-Process @startProcessArgs
            $exitcode = $newcode.exitcode

            if ($exitcode -ne "0") {
                $obj.status = "new failed"
                $failed = $true
            }
        } catch {
            $failed = $true
        }


        if (!($failed)) {
            $zipDirectory = Join-Path -Path $obj.versionDir  -ChildPath $obj.nuspecID -AdditionalChildPath "tools"
            $zipLocation = Join-Path -Path $zipDirectory -ChildPath "$($obj.nuspecID).zip"
            Copy-Item -Path $obj.origPath -Destination $zipLocation

            Remove-NupkgMetaData -Path $zipLocation

            if ($noPack) {
                $exitcode = 0
            } else {
                #start choco pack in the correct directory
                $startProcessArgs = @{
                    FilePath         = "choco"
                    ArgumentList     = 'pack -r'
                    WorkingDirectory = Join-Path -Path $obj.versionDir -ChildPath $obj.nuspecID
                    NoNewWindow      = $true
                    Wait             = $true
                    PassThru         = $true
                }

                $packcode = Start-Process @startProcessArgs
                $exitcode = $packcode.exitcode
            }

            if ($exitcode -ne "0") {
                $obj.status = "pack failed"
            } else {
                $obj.status = "internalized"
            }
        }
    }


    Foreach ($obj in $nupkgObjArray) {
        if (($obj.status -eq "internalized") -and (!($noSave))) {
            if ($config.useDropPath -eq "yes") {
                Write-Verbose "coping $($obj.nuspecID) to drop path"
                Copy-Item (Get-ChildItem (Join-Path -Path $obj.versionDir -ChildPath $obj.nuspecID) -Filter "*.nupkg").fullname $config.dropPath
            }

            if ($config.pushPkgs -eq "yes") {
                Write-Output "pushing $($obj.nuspecID)"
                $pushArgs = 'push -f -r -s ' + $config.pushURL
                $startProcessArgs = @{
                    FilePath         = "choco"
                    ArgumentList     = $pushArgs
                    WorkingDirectory = $obj.versionDir
                    NoNewWindow      = $true
                    Wait             = $true
                    PassThru         = $true
                }

                $pushcode = Start-Process @startProcessArgs
            }
            if (($config.pushPkgs -eq "yes") -and ($pushcode.exitcode -ne "0")) {
                $obj.status = "push failed"
            } else {
                $obj.status = "done"
                if ($config.writePerPkgs -eq "yes") {
                    Write-Verbose "writing $($obj.nuspecID) to internalized xml as internalized"
                    Write-InternalizedPSModulePackage -internalizedXMLPath $internalizedXML -Version $obj.version -nuspecID $obj.nuspecID
                }
            }
        } else {
            Write-Verbose "$($obj.nuspecID) $($obj.nuspecVersion) not internalized"
        }
    }


    Foreach ($obj in $nupkgObjArray) {
        Write-Output "$($obj.nuspecID) $($obj.Version) $($obj.status)"
    }


    if ($writeVersion) {
        Write-Output "`n"
        Foreach ($obj in $nupkgObjArray) {
            Write-Output "$($obj.nuspecID) $($obj.OldVersion) to $($obj.Version)"
        }
    }
}
