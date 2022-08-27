
<#

.SYNOPSIS

Remove NuGet/Chocolatey .nupkg MetaData from package archive.

.DESCRIPTION

Remove NuGet/Chocolatey .nupkg MetaData from package archive.

.PARAMETER Path

Path to .nupkg file


.EXAMPLE

PS> Remove-NupkgMetaData .\chocolatey.0.10.15.nupkg

.LINK


#>
Function Remove-NupkgMetaData {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true, Position = 0)]
        [ValidateScript( {
                if (!(Test-Path -Path $_ -PathType Leaf) ) {
                    throw "The Path parameter must be a file. Folder paths are not allowed."
                }
                return $true
            } )]
        [string]$Path
    )

    Begin {
        #needed for accessing dotnet zip functions
        Add-Type -AssemblyName System.IO.Compression.FileSystem
    }

    Process {
        Try {
            $Path = (Resolve-Path $Path).Path


            $archive = [System.IO.Compression.ZipFile]::Open($Path, 'update')

            #Making sure that none of the extra metadata files in the .nupkg are unpacked
            $metaDataArchive = $archive.Entries | `
                Where-Object { $_.Name -eq '[Content_Types].xml' -or $_.Name -eq '.rels'  `
                    -or $_.FullName -Like 'package/*' -or $_.Fullname -Like '__MACOSX/*'
            }


            $metaDataArchive | ForEach-Object {
                $_.Delete()
            }


        } Finally {
            #Always be sure to cleanup
            $archive.dispose()
        }
    }
}