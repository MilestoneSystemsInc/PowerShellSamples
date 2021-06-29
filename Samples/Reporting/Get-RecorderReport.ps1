function Get-RecorderReport {
    [CmdletBinding()]
    param (
        # Specifies one or more Recording Servers from which to generate a camera report. By default all Recording Servers will be used.
        [Parameter(ValueFromPipeline)]
        [VideoOS.Platform.ConfigurationItems.RecordingServer[]]
        $RecordingServer
    )

    begin {
        $runspacepool = [runspacefactory]::CreateRunspacePool(4, 16)
        $runspacepool.Open()
        $threads = New-Object System.Collections.Generic.List[pscustomobject]

        $process = {
            param(
                [VideoOS.Platform.ConfigurationItems.RecordingServer]$Recorder
            )
            try {
                $hardware = $recorder | Get-Hardware
                $cameras = $hardware | Get-Camera
                $enabledHardware = $hardware | Where-Object Enabled
                $enabledCameras = $cameras | Where-Object { $_.Enabled -and $_.ParentItemPath -in $enabledHardware.Path }

                $obj = [PSCustomObject]@{
                    RecordingServer = $recorder.Name
                    TotalHardware = $hardware.Count
                    EnabledHardware = $enabledHardware.Count
                    TotalCameras = $cameras.Count
                    EnabledCameras = $enabledCameras.Count
                    CamerasStarted = 0
                    UsedSpaceInBytes = 0
                    RecordedBPS = 0
                    TotalBPS = 0
                    OverflowCount = 0
                    CamerasWithErrors = 0
                    CamerasNotConnected = 0
                    DatabaseRepairsInProgress = 0
                    DatabaseWriteErrors = 0
                    CamerasNotLicensed = 0
                }

                try {
                    $svc = $recorder | Get-RecorderStatusService2
                    $stats = $svc.GetVideoDeviceStatistics((Get-Token), [guid[]]$enabledCameras.Id)
                    $status = $svc.GetCurrentDeviceStatus((Get-Token), [guid[]]$enabledCameras.Id)
                    $liveStreams = $stats.VideoStreamStatisticsArray | Where-Object RecordingStream -eq $false
                    $recordedStreams = $stats.VideoStreamStatisticsArray | Where-Object RecordingStream
                    $recordedBPS = $recordedStreams | Measure-Object -Property BPS -Sum | Select-Object -ExpandProperty Sum

                    $obj.CamerasStarted = ($status.CameraDeviceStatusArray | Where-Object Started).Count
                    $obj.UsedSpaceInBytes = $stats | Measure-Object -Property UsedSpaceInBytes -Sum | Select-Object -ExpandProperty Sum
                    $obj.RecordedBPS = $recordedBPS
                    $obj.TotalBPS = $recordedBPS + ( $liveStreams | Measure-Object -Property BPS -Sum | Select-Object -ExpandProperty Sum )
                    $obj.OverflowCount = ($status.CameraDeviceStatusArray | Where-Object ErrorOverflow).Count
                    $obj.CamerasWithErrors = ($status.CameraDeviceStatusArray | Where-Object Error).Count
                    $obj.CamerasNotConnected = ($status.CameraDeviceStatusArray | Where-Object ErrorNoConnection).Count
                    $obj.DatabaseRepairsInProgress = ($status.CameraDeviceStatusArray | Where-Object DbRepairInProgress).Count
                    $obj.DatabaseWriteErrors = ($status.CameraDeviceStatusArray | Where-Object ErrorWritingGop).Count
                    $obj.CamerasNotLicensed = ($status.CameraDeviceStatusArray | Where-Object CamerasNotLicensed).Count
                }
                catch {
                    Write-Error -Exception $_.Exception -Message "Error collecting statistics from $($recorder.Name) ($($recorder.Hostname))"
                }

                Write-Output $obj
            }
            catch {
                Write-Error -Exception $_.Exception -Message "Unexpected error: $($_.Message). $($recorder.Name) ($($recorder.Hostname)) will not be included in the report."
            }
            finally {
                $svc.Dispose()
            }
        }
    }

    process {
        $progressParams = @{
            Activity = $MyInvocation.MyCommand.Name
            CurrentOperation = ''
            PercentComplete = 0
            Completed = $false
        }

        if ($null -eq $RecordingServer) {
            $RecordingServer = Get-RecordingServer
        }

        try {
            foreach ($recorder in $RecordingServer) {
                $ps = [powershell]::Create()
                $ps.RunspacePool = $runspacepool
                $asyncResult = $ps.AddScript($process).AddParameters(@{
                    Recorder = $recorder
                }).BeginInvoke()
                $threads.Add([pscustomobject]@{
                    PowerShell = $ps
                    Result = $asyncResult
                })
            }

            if ($threads.Count -eq 0) {
                return
            }

            $progressParams.CurrentOperation = 'Processing requests for recorder information'
            $completedThreads = New-Object System.Collections.Generic.List[pscustomobject]
            $totalJobs = $threads.Count
            while ($threads.Count -gt 0) {
                $progressParams.PercentComplete = ($totalJobs - $threads.Count) / $totalJobs * 100
                $progressParams.Status = "Processed $($totalJobs - $threads.Count) out of $totalJobs requests"
                Write-Progress @progressParams
                foreach ($thread in $threads) {
                    if ($thread.Result.IsCompleted) {
                        $thread.PowerShell.EndInvoke($thread.Result)
                        $thread.PowerShell.Dispose()
                        $completedThreads.Add($thread)
                    }
                }
                $completedThreads | Foreach-Object { [void]$threads.Remove($_)}
                $completedThreads.Clear()
                if ($threads.Count -eq 0) {
                    break;
                }
                Start-Sleep -Seconds 1
            }
        }
        finally {
            if ($threads.Count -gt 0) {
                Write-Warning "Stopping $($threads.Count) running PowerShell instances. This may take a minute. . ."
                foreach ($thread in $threads) {
                    $thread.PowerShell.Dispose()
                }
            }
            $runspacepool.Close()
            $runspacepool.Dispose()
            $progressParams.Completed = $true
            Write-Progress @progressParams
        }
    }
}