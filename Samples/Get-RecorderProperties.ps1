function Get-RecorderProperties {
    <#
    .SYNOPSIS
        Gets the Device Pack and Hotfix version on the Recording Servers and Failover Recording Servers.
    .DESCRIPTION
        Gets the Device Pack and Hotfix version on the Recording Servers and Failover Recording Servers. If specified, it will add that
        information into the Description field of each Recording Server.

        This requires an environment that supports PSRemoting.
    .EXAMPLE
        PS C:\> Get-RecorderProperites | Out-GridView

        Displays the hostname, Device Pack version, Legacy Device Pack version (if installed), Hotfix version (if installed) and whether
        the recorder is a Primary or Failover.
    .EXAMPLE
        PS C:\> Get-RecorderProperties -AddToDescription

        Collects the Device Pack version, Legacy Device Pack version (if installed), Hotfix version (if installed) and adds them to the
        Description in the Management Client of each Recording Server. This will delete anything that is currently written in the Description
        field for the Recording Server.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [switch]$AddToDescription
    )

    $serverInfo = New-Object System.Collections.Generic.List[PSCustomObject]
    $recs = Get-VmsRecordingServer
    $failoverRecs = Get-VmsFailoverRecorder -Recurse

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
            [string]$ComputerName = $env:COMPUTERNAME
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
                        foreach ($UninstallKey in $UninstallKeys){
                            $friendlyNames = @{
                                'DisplayName'    = 'Name'
                                'DisplayVersion' = 'Version'
                            }
                            Write-Verbose -Message "Checking uninstall key [$($UninstallKey)]"
                            
                            $SwKeys = Get-ChildItem -Path $UninstallKey -ErrorAction SilentlyContinue | Where-Object { $_.GetValue('DisplayName') -like "Milestone*" -or $_.GetValue('DisplayName') -like "*XProtect*" }
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
            } catch {
                Write-Error -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
            }
        }
    }

    $serverIndex = 0
    $rsInfo = New-Object System.Collections.Generic.List[PSCustomObject]
    foreach ($server in $serverInfo) {
        Write-Progress -Activity "Getting info for $($server.Hostname)" -PercentComplete ($serverIndex / $serverInfo.Count * 100)
        if ([bool](Invoke-Command -ComputerName $server.Hostname -ScriptBlock {$env:COMPUTERNAME} -ErrorAction SilentlyContinue)) {
            $milestoneSoftware = Get-InstalledMilestoneSoftware -ComputerName $server.Hostname
            $dpVersion, $hotfixVersion, $legacyDPVersion = $null
            
            foreach ($entry in $milestoneSoftware) {
                if ($entry.Name -like "*XProtect*Device Pack*" -and $entry.Name -notlike "*Legacy*") {
                    $dpVersion = $entry.Version
                } elseif ($entry.Name -like "Milestone.Hotfix*") {
                    $hotfixVersion = $entry.Version
                } elseif ($entry.Name -like "*XProtect*Legacy Device*") {
                    $legacyDPVersion = $entry.Version
                }
            }

            $row = [PSCustomObject]@{
                'RecorderHostname' = $server.Hostname
                'DevicePackVersion' = $dpVersion
                'LegacyDPVersion' = $legacyDPVersion
                'HotfixVersion' = $hotfixVersion
                'Type' = $server.Type
            }
            $rsInfo.Add($row)
        } else {
            Write-Warning "Unable to remotely access Recording Server $($server.HostName). It will be skipped."
        }
        $serverIndex++
    }
    Write-Progress -Activity "Getting info for $($server.Hostname)" -Completed

    if ($AddToDescription)
    {
        $datetime = Get-Date
        $serverIndex = 0
        foreach ($rs in $rsInfo)
        {
            Write-Progress "Adding collected information to Description field of $($rs.RecorderHostname)" -PercentComplete ($serverIndex / $rsInfo.Count * 100)
            $rsDescriptionDate = "Last Updated = $($datetime)"
            $rsDescriptionDP = "`r`nDevice Pack Version = $($rs.DevicePackVersion)"
            $rsDescriptionLegacy = "`r`nLegacy Device Pack Version = $($rs.LegacyDPVersion)"
            $rsDescriptionHotfix = "`r`nHotfix Version = $($rs.HotfixVersion)"
            $rsDescription = $rsDescriptionDate + $rsDescriptionDP + $rsDescriptionLegacy + $rsDescriptionHotfix

            if ($rs.Type -eq 'Primary') {
                $recObject = $recs | Where-Object {$_.HostName -eq $rs.RecorderHostname}
            } elseif ($rs.Type -eq 'Failover') {
                $recObject = $failoverRecs | Where-Object {$_.HostName -eq $rs.RecorderHostname}
            }

            $recObject.Description = $rsDescription
            $recObject.Save()

            $serverIndex++
        }
        Write-Progress "Adding collected information to Description field of $($rs.RecorderHostname)" -Completed
    }
    else
    {
        $rsInfo | Select-Object RecorderHostname, DevicePackVersion, LegacyDPVersion, HotfixVersion, Type
    }
}