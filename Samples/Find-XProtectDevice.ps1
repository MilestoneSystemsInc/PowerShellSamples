function Find-XProtectDevice {
    <#
    .SYNOPSIS
        Search for any string of text related to hardware or any device attached to hardware.
    .DESCRIPTION
        Search the properties for any string related to hardware or cameras, microphones, speakers, metadata channels, inputs, or outputs attached to hardware.  All results will return the Recording Server and Hardware that the device is attached to.
    .EXAMPLE
        Find-XProtectDevice -ItemType Hardware -SearchString "10.1.10.30" -EnabledOnly

        Searches for any Enabled hardware with "10.1.10.30" existing on any of its properties
    .EXAMPLE
        Find-XProtectDevice -ItemType Camera -SearchString "Northwest"

        Searches for any camera (enabled or disabled) with "Northwest" existing on any of its properties
    .EXAMPLE
        Find-XProtectDevice -ItemType Speaker -SearchString parking*entrance -EnabledOnly

        Searches for any Enabled speaker that has the words "parking" and "entrance" (in that order)
    .EXAMPLE
        Find-XProtectDevice -ItemType Hardware -SearchString dd*be

        When searching for a MAC address, seperate each octet with an asterisk (*) because some MAC addresses are stored with the separating colons and some are stored without the separating colons.  By using the asterisk, it will catch it either way.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        [ValidateSet('Hardware','Camera','Microphone','Speaker','Metadata','Input','Output')]
        $ItemType,
        [Parameter(Mandatory)]
        [string]
        $SearchString,
        [Parameter()]
        [switch]
        $EnabledOnly
    )
    process {
        $recs = Get-RecordingServer

        if ($EnabledOnly -eq $true)
        {
            $hw = Get-Hardware | Where-Object Enabled
            switch ($ItemType) {
                'Hardware' {$items = $hw | Where-Object Enabled}
                'Camera' {$items = $hw | Get-Camera | Where-Object Enabled}
                'Microphone' {$items = $hw | Get-Microphone | Where-Object Enabled}
                'Speaker' {$items = $hw | Get-Speaker | Where-Object Enabled}
                'Metadata' {$items = $hw | Get-Metadata | Where-Object Enabled}
                'Input' {$items = $hw | Get-Input | Where-Object Enabled}
                'Output' {$items = $hw | Get-Output | Where-Object Enabled}
            }
        } else {
            $hw = Get-Hardware
            switch ($ItemType) {
                'Hardware' {$items = $hw}
                'Camera' {$items = $hw | Get-Camera}
                'Microphone' {$items = $hw | Get-Microphone}
                'Speaker' {$items = $hw | Get-Speaker}
                'Metadata' {$items = $hw | Get-Metadata}
                'Input' {$items = $hw | Get-Input}
                'Output' {$items = $hw | Get-Output}
            }
        }

        $found = New-Object System.Collections.Generic.List[PSCustomObject]

        if ($ItemType -ne 'Hardware')
        {
            foreach ($device in $items)
            {
                $deviceHash = Convert-ObjectToHashTable $device
                $deviceHash.GetEnumerator() | ForEach-Object {
                    if ($null -ne $_.Value -and $_.Value -like "*$($SearchString)*")
                    {
                        $hwObject = $hw | Where-Object {$device.ParentItemPath -eq $_.Path}

                        $hwName = $hwObject.Name
                        $recObject = $recs | Where-Object {$hwObject.ParentItemPath -eq $_.Path}
                        $recName = $recObject.Name

                        $row = [PSCustomObject]@{
                            'RecordingServer' = $recName
                            'HardwareName' = $hwName
                            'DeviceName' = $device
                        }
                        $found.Add($row)
                    }
                }
            }
            $foundSorted = $found | Sort-Object RecordingServer, HardwareName, DeviceName -Unique
        } else
        {
            foreach ($hardware in $items)
            {
                $hardwareSettings = $hardware | Get-HardwareSetting

                $hardwareHash = Convert-ObjectToHashTable $hardware
                $hardwareSettingsHash = Convert-ObjectToHashTable $hardwareSettings
                $allHardwareInfoHash = $hardwareHash + $hardwareSettingsHash
                $allHardwareInfoHash.GetEnumerator() | ForEach-Object {
                    if ($null -ne $_.Value -and $_.Value -like "*$($SearchString)*")
                    {
                        $recObject = $recs | Where-Object {$hardware.ParentItemPath -eq $_.Path}
                        $recName = $recObject.Name

                        $row = [PSCustomObject]@{
                            'RecordingServer' = $recName
                            'HardwareName' = $hardware.Name
                        }
                        $found.Add($row)
                    }
                }
            }
            $foundSorted = $found | Sort-Object RecordingServer, HardwareName -Unique
        }
    }
    end {
        if ($null -ne $foundSorted)
        {
            $foundSorted
        } else {
            Write-Host "No results found!" -ForegroundColor Green
        }
    }
}

function Convert-ObjectToHashTable
{
    <#
    .SYNOPSIS
        Converts an Object to a Hash Table
    #>
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [pscustomobject] $Object
    )
    $HashTable = @{}
    $ObjectMembers = Get-Member -InputObject $Object -MemberType *Property
    foreach ($Member in $ObjectMembers)
    {
        $HashTable.$($Member.Name) = $Object.$($Member.Name)
    }
    return $HashTable
}