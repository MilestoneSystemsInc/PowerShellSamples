#Requires -Modules MilestonePSTools
function Get-VmsCameraDiskUsage {
    <#
    .SYNOPSIS
        Gets the amount of space used for all cameras
    .DESCRIPTION
        Gets the amount of space used for all cameras
    .EXAMPLE
        PS C:\> Get-VmsCameraDiskUsage | Out-GridView
        Gets the disk usage information for all cameras and all storages used by those cameras and displays them in a grid view
    #>

    begin {
        $offlineRecorders = New-Object System.Collections.Generic.List[PSCustomObject]
        $svc = Get-IServerCommandService
        $config = $svc.GetConfiguration((Get-Token))
    }

    process {
        #$config.Recorders | ForEach-Object {
        foreach ($recInfo in $config.Recorders) {
            #$recInfo = $_
            $statusSvc = Get-RecorderStatusService2 -RecordingServer (Get-VmsRecordingServer -Id $recInfo.RecorderId) -ErrorAction SilentlyContinue
            try {
                $stats = $statusSvc.GetVideoDeviceStatistics((Get-Token), $recInfo.Cameras.DeviceId)
            } catch {
                $offlineRecorders.Add($recInfo.Name)
            }
        
            $statsHash = @{}
            $stats | ForEach-Object {
                $statsHash[$_.DeviceId] = $_
            }
        
            foreach ($hw in $recInfo.Hardware){
                if ($hw.Disabled -eq $true) {
                    Break
                }
                foreach ($cam in Get-VmsCamera -Hardware (Get-VmsHardware -Id $hw.HardwareId) -EnableFilter Enabled) {                        
                    if (-not [string]::IsNullOrEmpty($statsHash[[guid]$cam.Id])) {
                        [pscustomobject]@{
                            Camera = $cam.Name
                            Hardware = $hw.Name
                            Recorder = $recInfo.Name
                            'UsedSpace(GB)' = [math]::Round(($statsHash[[guid]$cam.Id] | Select-Object -Expand UsedSpaceInBytes) / 1GB,2)
                        }
                    } else {
                        [pscustomobject]@{
                            Camera = $cam.Name
                            Hardware = $hw.Name
                            Recorder = $recInfo.Name
                            'UsedSpace(GB)' = "Unknown"
                        }
                    }
                }
            }
        }
    }
    
    end {
        if (-not [string]::IsNullOrEmpty($offlineRecorders[0])) {
            foreach ($offlineRecorder in $offlineRecorders) {
                Write-Warning "Recording Server $($offlineRecorder) was unavailable and was skipped."
            }
        }
    }
}