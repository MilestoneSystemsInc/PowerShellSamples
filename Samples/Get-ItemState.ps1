$itemKinds = @(
    [VideoOS.Platform.Kind]::Camera,
    [VideoOS.Platform.Kind]::Hardware)


$list = New-Object System.Collections.Generic.List[object]
foreach ($result in Get-ItemState) {
    
    if (-not $itemKinds.Contains($result.FQID.Kind)) {
        continue
    }
        
    $item = $result.FQID | Get-PlatformItem
    
    $address = $null
    if ($result.State -ne "Responding") {
        if ($result.FQID.Kind -eq [VideoOS.Platform.Kind]::Hardware) {
            $address = (Get-Hardware -HardwareId $result.FQID.ObjectId).Address
        }
        else {
            $camera = Get-Camera -Id $result.FQID.ObjectId
            $hardware = Get-ConfigurationItem -Path $camera.ParentItemPath
            $address = ($hardware.Properties | Where-Object Key -eq Address).Value
        }
    }

    $entry = [pscustomobject]@{
        Name = $item.Name
        State = $result.State
        Type = [VideoOS.Platform.Kind]::DefaultTypeToNameTable[$result.FQID.Kind]
        Address = $address
    }

    $entry
    $list.Add($entry)
}

$list | Out-GridView