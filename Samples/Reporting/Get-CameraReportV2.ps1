function Get-CameraReportV2 {
    <#
    .SYNOPSIS
        Gets detailed information for all cameras in the current site
    .DESCRIPTION
        A rewrite of Get-CameraReport with support for multi-threading using runspaces.
    .EXAMPLE
        PS C:\> Get-CameraReportV2 | Out-GridView -Passthru | Export-Csv -Path .\camera-report.csv -NoTypeInformation
        Gets a camera report and displays the contents using Out-GridView, as well as passing reach row to Export-Csv to generate
        a CSV report.
    #>
    [CmdletBinding()]
    param (
        # Specifies one or more Recording Servers from which to generate a camera report
        [Parameter(ValueFromPipeline)]
        [VideoOS.Platform.ConfigurationItems.RecordingServer[]]
        $RecordingServer,

        # Include plain text hardware passwords in the report
        [Parameter()]
        [switch]
        $IncludePlainTextPasswords
    )

    begin {
        $runspacepool = [runspacefactory]::CreateRunspacePool(4, 16)
        $runspacepool.Open()
        $threads = New-Object System.Collections.Generic.List[pscustomobject]

        $processDevice = {
            param(
                [VideoOS.Platform.Messaging.ItemState[]]$States,
                [VideoOS.Platform.ConfigurationItems.RecordingServer]$RecordingServer,
                [VideoOS.Platform.ConfigurationItems.Hardware]$Hardware,
                [VideoOS.Platform.ConfigurationItems.Camera]$Camera,
                [bool]$IncludePasswords
            )

            function ConvertFrom-GisPoint {
                param ([string]$GisPoint)
            
                if ($GisPoint -eq 'POINT EMPTY') {
                    return [string]::Empty
                }
            
                $temp = $GisPoint.Substring(7, $GisPoint.Length - 8)
                $long, $lat, $null = $temp -split ' '
                return "$lat, $long"
            }
            $motionDetection = $Camera.MotionDetectionFolder.MotionDetections[0]
            $hardwareSettings = $Hardware | Get-HardwareSetting
            $playbackInfo = $Camera | Get-PlaybackInfo -ErrorAction Ignore -WarningAction Ignore
            $driver = $Hardware | Get-HardwareDriver
            $password = ''
            if ($IncludePasswords) {
                try {
                    $password = $Hardware | Get-HardwarePassword -ErrorAction Ignore
                }
                catch {
                    $password = $_.Message
                }
            }
            [pscustomobject]@{
                Name = $Camera.Name
                Channel = $Camera.Channel
                Enabled = $Camera.Enabled
                State = $States | Where-Object { $_.FQID.ObjectId -eq $Camera.Id } | Select-Object -ExpandProperty State
                NetworkState = 'NotImplemented'
                Location = ConvertFrom-GisPoint -GisPoint $Camera.GisPoint
                LastModified = $Camera.LastModified
                Id = $Camera.Id
                HardwareName = $Hardware.Name
                Address = $Hardware.Address
                Username = $Hardware.UserName
                Password = $password
                MAC = $hardwareSettings.MacAddress
                Firmware = $hardwareSettings.FirmwareVersion
                Model = $Hardware.Model
                Driver = $driver.Name
                DriverNumber = $driver.Number.ToString()
                DriverRevision = $driver.DriverRevision
                HardwareId = $Hardware.Id
                RecorderName = $RecordingServer.Name
                RecorderHostname = $RecordingServer.HostName
                RecorderId = $RecordingServer.Id

                RecordingEnabled = $Camera.RecordingEnabled
                RecordKeyframesOnly = $Camera.RecordKeyframesOnly
                RecordOnRelatedDevices = $Camera.RecordOnRelatedDevices
                PrebufferEnabled = $Camera.PrebufferEnabled
                PrebufferSeconds = $Camera.PrebufferSeconds
                PrebufferInMemory = $Camera.PrebufferInMemory

                MotionEnabled = $motionDetection.Enabled
                MotionKeyframesOnly = $motionDetection.KeyframesOnly
                MotionProcessTime = $motionDetection.ProcessTime
                MotionSensitivityMode = if ($motionDetection.ManualSensitivityEnabled) { 'Manual' } else { 'Automatic' }
                MotionManualSensitivity = $motionDetection.ManualSensitivity
                MotionMetadataEnabled = $motionDetection.GenerateMotionMetadata
                MotionExcludeRegions = if ($motionDetection.UseExcludeRegions) { 'Yes' } else { 'No' }
                MotionHardwareAccelerationMode = $motionDetection.HardwareAccelerationMode

                MediaDatabaseBeginning = $playbackInfo.Begin
                MediaDatabaseEnd = $playbackInfo.End
            }
        }
    }
    
    process {
        $progressParams = @{
            Activity = 'Camera Report'
            CurrentOperation = ''
            PercentComplete = 0
            Completed = $false
        }
        if ($null -eq $RecordingServer) {
            Write-Verbose "Getting a list of all recording servers on $((Get-ManagementServer).Name)"
            $progressParams.CurrentOperation = 'Getting Recording Servers'
            Write-Progress @progressParams
            $RecordingServer = Get-RecordingServer
        }

        Write-Verbose 'Getting the current state of all cameras'
        $progressParams.CurrentOperation = 'Calling Get-ItemState -CamerasOnly'
        Write-Progress @progressParams
        $itemState = Get-ItemState -CamerasOnly -ErrorAction Stop

        Write-Verbose 'Discovering all cameras'
        $progressParams.CurrentOperation = 'Discovering cameras'
        Write-Progress @progressParams

        try {
            foreach ($rs in $RecordingServer | Sort-Object Name) {
                foreach ($hw in $rs | Get-Hardware | Sort-Object Name) {
                    foreach ($cam in $hw | Get-Camera | Sort-Object Channel) {
                        $ps = [powershell]::Create()
                        $ps.RunspacePool = $runspacepool
                        $asyncResult = $ps.AddScript($processDevice).AddParameters(@{
                            State = $itemState
                            RecordingServer = $rs
                            Hardware = $hw
                            Camera = $cam
                            IncludePasswords = $IncludePlainTextPasswords
                        }).BeginInvoke()
                        $threads.Add([pscustomobject]@{
                            PowerShell = $ps
                            Result = $asyncResult
                        })
                    }
                }
            }

            if ($threads.Count -eq 0) {
                return
            }
            $progressParams.CurrentOperation = 'Processing requests for camera information'
            $completedThreads = New-Object System.Collections.Generic.List[pscustomobject]
            $totalDevices = $threads.Count
            while ($threads.Count -gt 0) {
                $progressParams.PercentComplete = ($totalDevices - $threads.Count) / $totalDevices * 100
                $progressParams.Status = "Processed $($totalDevices - $threads.Count) out of $totalDevices requests"
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