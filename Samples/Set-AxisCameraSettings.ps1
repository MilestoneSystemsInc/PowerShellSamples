function Set-AxisCameraSettings {
    <#
    .SYNOPSIS
        Set Axis Zipstream settings, as well as frame rate
    .DESCRIPTION
        Quickly set some or all of the Axis Zipstream settings, as well as frame rate, on all streams or just the recorded or just the live
    .EXAMPLE
        Set-AxisCameraSettings -RecordingServerName * -StreamType Recorded -FPS 10 -ZipstreamCompression medium -ZipstreamFPSMode dynamic

        Sets the Record stream on all Axis cameras on all Recording Servers to 10 fps, Medium zipstream, and Dynamic FPS mode.
    .EXAMPLE
        Set-AxisCameraSettings -RecordingServerName "Milestone-RS" -StreamType LiveDefault -FPS 15 -ZipstreamGOPMode dynamic -ZipstreamMaxGOPLength 500

        Sets the Live stream on all Axis cameras on Recording Server "Milestone-RS" to 15fps, Dynamic GOP length, and a max GOP length of 500.
    .EXAMPLE
        Set-AxisCameraSettings -RecordingServerName * -StreamType All -FPS 8 -ZipstreamCompress extreme

        Sets all streams on all Axis cameras on all Recording Servers to 8fps and Extreme zipstream.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $RecordingServerName,
        [Parameter(Mandatory = $true)]
        [ValidateSet("All","LiveDefault","Recorded")]
        $StreamType,
        [Parameter()]
        [ValidateRange(1,30)]
        $FPS,
        [Parameter()]
        [ValidateSet("off","low","medium","high","higher","extreme")]
        $ZipstreamCompression,
        [Parameter()]
        [ValidateSet("fixed","dynamic")]
        $ZipstreamFPSMode,
        [Parameter()]
        [ValidateSet("fixed","dynamic")]
        $ZipstreamGOPMode,
        [Parameter()]
        [ValidateRange(62,1200)]
        $ZipstreamMaxGOPLength
    )

    begin
    {
        if ($RecordingServerName -ne "*" -and (Get-RecordingServer).Name -notcontains $RecordingServerName)
        {
            Write-Host "Recording Server does not exist.  Please check spelling and try again." -ForegroundColor Red
            Return
        }
    }

    process
    {
        foreach ($rec in Get-RecordingServer -Name $RecordingServerName)
        {
            $hwProcessed = 1
            $allAxisHardware = Get-Hardware | Where-Object {$_.Enabled -and ($_ | Get-HardwareSetting).ProductID -like "*Axis*"}
            $hwQty = $allAxisHardware.Count
            foreach ($hardware in $allAxisHardware)
            {
                Write-Progress -Activity "Processing hardware $($hwProcessed) of $($hwQty)" -PercentComplete ($hwProcessed / $hwQty * 100)
                foreach ($camera in $hardware | Get-Camera | Where-Object Enabled)
                {
                    $allStreams = $camera | Get-Stream -All

                    if ($StreamType -eq "Recorded")
                    {
                        $streamNum = 0
                        foreach ($stream in $allStreams)
                        {
                            if ($stream.Record -ne $true)
                            {
                                $streamNum++
                            } else
                            {
                                Break
                            }
                        }
                    }

                    if ($StreamType -eq "LiveDefault")
                    {
                        $streamNum = 0
                        foreach ($stream in $allStreams)
                        {
                            if ($stream.LiveDefault -ne $true)
                            {
                                $streamNum++
                            } else
                            {
                                Break
                            }
                        }
                    }

                    if ($StreamType -eq "Recorded" -or $StreamType -eq "LiveDefault")
                    {
                        $cameraSettings = $camera | Get-CameraSetting -Stream -StreamNumber $streamNum

                        if ($null -ne $FPS -and $null -ne $cameraSettings.FPS)
                        {
                            $camera | Set-CameraSetting -Stream -StreamNumber $streamNum -Name FPS -Value $FPS
                        }

                        if ($null -ne $ZipstreamCompression -and $null -ne $cameraSettings.ZStrength)
                        {
                            $camera | Set-CameraSetting -Stream -StreamNumber $streamNum -Name ZStrength -Value $ZipstreamCompression
                        }

                        if ($null -ne $ZipstreamFPSMode -and $null -ne $cameraSettings.ZFpsMode)
                        {
                            $camera | Set-CameraSetting -Stream -StreamNumber $streamNum -Name ZFpsMode -Value $ZipstreamFPSMode
                        }

                        if ($null -ne $ZipstreamGOPMode -and $null -ne $cameraSettings.ZGopMode)
                        {
                            $camera | Set-CameraSetting -Stream -StreamNumber $streamNum -Name ZGopMode -Value $ZipstreamGOPMode
                        }

                        if ($null -ne $ZipstreamMaxGOPLength -and $null -ne $cameraSettings.ZGopLength)
                        {
                            $camera | Set-CameraSetting -Stream -StreamNumber $streamNum -Name ZGopLength -Value $ZipstreamMaxGOPLength
                        }
                    }

                    if ($StreamType -eq "All")
                    {
                        for ($streamNum = 0;$streamNum -lt $allStreams.Count;$streamNum++)
                        {
                            $cameraSettings = $camera | Get-CameraSetting -Stream -StreamNumber $streamNum

                            if ($null -ne $FPS -and $null -ne $cameraSettings.FPS)
                            {
                                $camera | Set-CameraSetting -Stream -StreamNumber $streamNum -Name FPS -Value $FPS
                            }

                            if ($null -ne $ZipstreamCompression -and $null -ne $cameraSettings.ZStrength)
                            {
                                $camera | Set-CameraSetting -Stream -StreamNumber $streamNum -Name ZStrength -Value $ZipstreamCompression
                            }

                            if ($null -ne $ZipstreamFPSMode -and $null -ne $cameraSettings.ZFpsMode)
                            {
                                $camera | Set-CameraSetting -Stream -StreamNumber $streamNum -Name ZFpsMode -Value $ZipstreamFPSMode
                            }

                            if ($null -ne $ZipstreamGOPMode -and $null -ne $cameraSettings.ZGopMode)
                            {
                                $camera | Set-CameraSetting -Stream -StreamNumber $streamNum -Name ZGopMode -Value $ZipstreamGOPMode
                            }

                            if ($null -ne $ZipstreamMaxGOPLength -and $null -ne $cameraSettings.ZGopLength)
                            {
                                $camera | Set-CameraSetting -Stream -StreamNumber $streamNum -Name ZGopLength -Value $ZipstreamMaxGOPLength
                            }
                        }
                    }
                }
                $hwProcessed++
            }
        }
    }
}