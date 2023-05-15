function Get-CameraConnectivityReport {
    <#
    .SYNOPSIS
        Gets report of number of times cameras were offline over specified period and if the camera is still offline.
    .DESCRIPTION
        Gets report of number of times cameras were offline over specified period and if the camera is still offline.
    .EXAMPLE
        Connect-ManagementServer -ShowDialog -Force
        Get-CameraConnectivityReport -DurationDays 3

        Returns a report of number of times cameras were offline over the last 3 days and if they are still offline
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [int]
        $DurationDays
    )

    $camStatus = New-Object System.Collections.Generic.List[PSCustomObject]
    $commErrors = Get-VmsLog -LogType System -StartTime (Get-Date).AddDays(-$DurationDays) -EndTime (Get-Date) | Where-Object {$_.'Message text' -eq "Communication error." -and $_.'Source type' -eq "Device"}
    $groupedCommErrors = $commErrors.'Source name' | Group-Object

    foreach($rec in Get-VmsRecordingServer -Name "JMT-XPCO")
    {
        $deviceStatus = Get-VmsDeviceStatus -RecordingServerId $rec.Id -DeviceType Camera
        foreach($hw in $rec | Get-VmsHardware | Where-Object Enabled)
        {
            foreach($cam in $hw | Get-VmsCamera | Where-Object Enabled)
            {
                if(($groupedCommErrors | Where-Object {$_.Name -eq $cam.Name}).Count -gt 0)
                {
                    $offlineCount = ($groupedCommErrors | Where-Object {$_.Name -eq $cam.Name}).Count
                } else {
                    $offlineCount = 0
                }

                $row = [PSCustomObject]@{
                    RecordingServer = $rec.Name
                    Hardware = $hw.Name
                    Camera = $cam.Name
                    NumberOfTimesOffline = $offlineCount
                    "StillOffline?" = ($deviceStatus | Where-Object DeviceName -eq $cam.Name).Error
                }
                $camStatus.Add($row)
            }
        }
    }
    $camStatus | Out-GridView
}