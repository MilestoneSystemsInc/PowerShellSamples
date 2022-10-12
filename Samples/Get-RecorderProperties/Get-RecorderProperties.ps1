function Get-RecorderProperties {
    <#
    .SYNOPSIS
        Gets the Device Pack and Hotfix version on the Recording Servers
    .DESCRIPTION
        Gets the Device Pack and Hotfix version on the Recording Servers.  If specified, it will add that information into the Description field of each Recording Server.
    .EXAMPLE
        PS C:\> Get-RecorderProperites | Out-GridView

        Displays the hostname, Device Pack version, Legacy Device Pack version (if installed), Hotfix version (if installed) and whether the recorder is a Primary or Failover.
    .EXAMPLE
        PS C:\> Get-RecorderProperties -AddToDescription

        Collects the Device Pack version, Legacy Device Pack version (if installed), Hotfix version (if installed) and adds them to the Description in the Management Client of each Recording Server.
        This will delete anything that is currently written in the Description field for the Recording Server.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [switch]$AddToDescription
    )

    $serverInfo = New-Object System.Collections.Generic.List[PSCustomObject]
    $recs = Get-RecordingServer
    $failoverRecs = (Get-VmsFailoverGroup).FailoverRecorderFolder.FailoverRecorders
    $servers = @($recs,$failoverRecs)
    $hostnames = $servers.hostname

    foreach ($rec in $recs)
    {
        $row = [PSCustomObject]@{
            'Hostname' = $rec.HostName
            'Type' = "Primary"
        }
        $serverInfo.Add($row)
    }

    foreach ($failoverRec in $failoverRecs)
    {
        $row = [PSCustomObject]@{
            'Hostname' = $failoverRec.HostName
            'Type' = "Failover"
        }
        $serverInfo.Add($row)
    }

    # Get-InstalledMilestoneSoftware courtesy of Adam the Automator (https://adamtheautomator.com/powershell-list-installed-software/)
    function Get-InstalledMilestoneSoftware {

        [CmdletBinding()]
        param (

            [Parameter()]
            [ValidateNotNullOrEmpty()]
            [string]$ComputerName = $env:COMPUTERNAME,

            [Parameter()]
            [ValidateNotNullOrEmpty()]
            [string]$Name,

            [Parameter()]
            [guid]$Guid
        )
        process {
            try {
                $scriptBlock = {
                    $args[0].GetEnumerator() | ForEach-Object { New-Variable -Name $_.Key -Value $_.Value }

                    $UninstallKeys = @(
                        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
                        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
                    )
                    New-PSDrive -Name HKU -PSProvider Registry -Root Registry::HKEY_USERS | Out-Null
                    $UninstallKeys += Get-ChildItem HKU: | Where-Object { $_.Name -match 'S-\d-\d+-(\d+-){1,14}\d+$' } | ForEach-Object {
                        "HKU:\$($_.PSChildName)\Software\Microsoft\Windows\CurrentVersion\Uninstall"
                    }
                    if (-not $UninstallKeys) {
                        Write-Warning -Message 'No software registry keys found'
                    } else {
                        foreach ($UninstallKey in $UninstallKeys | Where-Object {$_.Name -like "*Milestone*" -or $_.Name -like "*XProtect*"} ) {
                            $friendlyNames = @{
                                'DisplayName'    = 'Name'
                                'DisplayVersion' = 'Version'
                            }
                            Write-Verbose -Message "Checking uninstall key [$($UninstallKey)]"
                            if ($Name) {
                                $WhereBlock = { $_.GetValue('DisplayName') -like "$Name*" }
                            } elseif ($GUID) {
                                $WhereBlock = { $_.PsChildName -eq $Guid.Guid }
                            } else {
                                $WhereBlock = { $_.GetValue('DisplayName') }
                            }
                            $SwKeys = Get-ChildItem -Path $UninstallKey -ErrorAction SilentlyContinue | Where-Object $WhereBlock
                            if (-not $SwKeys) {
                                Write-Verbose -Message "No software keys in uninstall key $UninstallKey"
                            } else {
                                foreach ($SwKey in $SwKeys) {
                                    $output = @{ }
                                    foreach ($ValName in $SwKey.GetValueNames()) {
                                        if ($ValName -ne 'Version') {
                                            $output.InstallLocation = ''
                                            if ($ValName -eq 'InstallLocation' -and
                                                ($SwKey.GetValue($ValName)) -and
                                                (@('C:', 'C:\Windows', 'C:\Windows\System32', 'C:\Windows\SysWOW64') -notcontains $SwKey.GetValue($ValName).TrimEnd('\'))) {
                                                $output.InstallLocation = $SwKey.GetValue($ValName).TrimEnd('\')
                                            }
                                            [string]$ValData = $SwKey.GetValue($ValName)
                                            if ($friendlyNames[$ValName]) {
                                                $output[$friendlyNames[$ValName]] = $ValData.Trim() ## Some registry values have trailing spaces.
                                            } else {
                                                $output[$ValName] = $ValData.Trim() ## Some registry values trailing spaces
                                            }
                                        }
                                    }
                                    $output.GUID = ''
                                    if ($SwKey.PSChildName -match '\b[A-F0-9]{8}(?:-[A-F0-9]{4}){3}-[A-F0-9]{12}\b') {
                                        $output.GUID = $SwKey.PSChildName
                                    }
                                    New-Object -TypeName PSObject -Prop $output
                                }
                            }
                        }
                    }
                }

                if ($ComputerName -eq $env:COMPUTERNAME) {
                    & $scriptBlock $PSBoundParameters
                } else {
                    Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock -ArgumentList $PSBoundParameters
                }

                if ($null -eq (get-service | Where-Object {$_.Name -eq "Milestone XProtect Failover Server"}))
                {
                    $rsType = "Primary"
                } else
                {
                    $rsType = "Failover"
                }
            } catch {
                Write-Error -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
            }
        }
    }
    $milestoneSoftware = Get-InstalledSoftware -ComputerName $hostnames | Where-Object {$_.Name -like "*Milestone*" -or $_.Name -like "*XProtect*"}


    if ($AddToDescription)
    {
        $datetime = Get-Date
        foreach ($rs in $rsInfo)
        {
            $rsDescriptionDate = "Last Updated = $($datetime)"
            $rsDescriptionDP = "`r`nDevice Pack Version = $($rs.DevicePackVersion)"
            $rsDescriptionLegacy = "`r`nLegacy Device Pack Version = $($rs.LegacyDPVersion)"
            $rsDescriptionHotfix = "`r`nHotfix Version = $($rs.HotfixVersion)"
            $rsDescription = $rsDescriptionDate + $rsDescriptionDP + $rsDescriptionLegacy + $rsDescriptionHotfix

            if ($null -ne (Get-RecordingServer -Hostname $rs.RecorderHostname -ErrorAction SilentlyContinue))
            {
                $recObject = Get-RecordingServer -Hostname $rs.RecorderHostname
            }
            else
            {
                $recObject = (Get-VmsFailoverGroup).FailoverRecorderFolder.FailoverRecorders | Where-Object {$_.Hostname -eq $rs.RecorderHostname}
            }
            $r = Get-ConfigurationItem -Path $recObject.Path
            $description = $r.Properties | Where-Object Key -eq "Description"
            $description.Value = $rsDescription
            $multicastAddress = $r.Properties | Where-Object Key -eq "MulticastServerAddress"
            if ([string]::IsNullOrEmpty($multicastAddress.Value))
            {
                $multicastAddress.Value = "0.0.0.0"
            }
            $null = $r | Set-ConfigurationItem

        }
    }
    else
    {
        $rsInfo | Select-Object RecorderHostname, DevicePackVersion, LegacyDPVersion, HotfixVersion, Type
    }
}