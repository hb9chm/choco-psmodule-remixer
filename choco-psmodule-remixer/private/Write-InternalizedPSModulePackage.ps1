Function Write-InternalizedPSModulePackage {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)][string]$version,
        [parameter(Mandatory = $true)][string]$nuspecID,
        [parameter(Mandatory = $true)][string]$internalizedXMLPath
    )

    $nuspecID = $nuspecID.tolower()
    [XML]$internalizedXMLcontent = Get-Content $internalizedXMLPath

    if ($internalizedXMLcontent.internalized.pspkg.id -notcontains "$nuspecID") {
        Write-Verbose "adding $nuspecID to internalized IDs"
        $addID = $internalizedXMLcontent.CreateElement("pspkg")
        $addID.SetAttribute("id", "$nuspecID")
        $internalizedXMLcontent.internalized.AppendChild($addID) | Out-Null
        $internalizedXMLcontent.save($internalizedXMLPath)

        [XML]$internalizedXMLcontent = Get-Content $internalizedXMLPath
    }

    # no duplicate versions
    if (-not ($internalizedXMLcontent.SelectSingleNode("//pspkg[@id=""$nuspecID""]/version[""$version""]"))) {
        Write-Verbose "adding $nuspecID $version to list of internalized packages"
        $addVersion = $internalizedXMLcontent.CreateElement("version")
        $null = $addVersion.AppendChild($internalizedXMLcontent.CreateTextNode("$version"))
        $internalizedXMLcontent.SelectSingleNode("//pspkg[@id=""$nuspecID""]").appendchild($addVersion) | Out-Null
        $internalizedXMLcontent.save($internalizedXMLPath)
    }
}