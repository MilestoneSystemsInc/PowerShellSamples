function Test-VmsBestPractices
{
    <#
    .SYNOPSIS
        Finds cameras that have non-default settings that may affect performance or function. If a field is blank, it means it is following
        Milestone best practices. Cameras will only be displayed if they have at least one area that isn't following best practices.

    .DESCRIPTION
        Finds cameras that lack any of the following features or have any of the following settings:
         - No support for HTTPS
         - Supports HTTPS but HTTPS isn't enabled
         - Motion on keyframes disabled unless custom GOP or Dynamic GOP is enabled
         - Custom GOP on record stream unless Motion on keyframes is disabled
         - Dynamic GOP on record stream on Axis cameras unless Motion on keyframes is disabled
         - Hardware acceleration for motion detection disabled
         - Generate motion data for Smart Search disabled
         - Can check if framerates are above, below or equal to a certain value.
         - Recording stream not set to best codec (e.g., set to MJPEG when h.264 is available).  For this test, h.264 and h.265 are considered equal.
         - Record stream not set to highest resolution
         - If using Expert or Corporate, cameras not having more than one stream configured so that Adaptive Streaming can be used.

        Checking the framerate, resolution, and codec does not work on all cameras due to how some cameras display that information.

    .EXAMPLE
        Test-VmsBestPractices

        Creates a report of any cameras that have settings that are considered not best practices.  This doesn't check the frame rate at all.

    .EXAMPLE
        Test-VmsBestPractices -FPSNotEqualTo 10

        Creates a report of any cameras that have settings that are considered not best practices and if any cameras don't have their framerate set to 10fps

    .EXAMPLE
        Test-VmsBestPractices -FPSAbove 15

        Creates a report of any cameras that have settings that are considered not best practices and if any cameras have a framerate above 15ps.

    .EXAMPLE
        Test-VmsBestPractices -FPSBelow 10

        Creates a report of any cameras that have settings that are considered not best practices and if any cameras have a framerate below 10fps.

    .EXAMPLE
        Test-VmsBestPractices -FPSAbove 20 -FPSBelow 10

        Creates a report of any cameras that have settings that are considered not best practices and if any cameras have a framerate above 20fps and below 10fps
    #>

    [CmdletBinding(DefaultParameterSetName='AboveBelow')]
    param (
        [Parameter(Mandatory=$false,ParameterSetName='AboveBelow')]
        [ValidateRange(1,120)]
        $FPSAbove,
        [Parameter(Mandatory=$false,ParameterSetName='AboveBelow')]
        [ValidateRange(1,120)]
        $FPSBelow,
        [Parameter(Mandatory=$false,ParameterSetName='EqualTo')]
        [ValidateRange(1,120)]
        $FPSNotEqualTo
    )

    if ($null -ne $FPSAbove -and $null -ne $FPSBelow -and $FPSAbove -le $FPSBelow)
    {
        Write-Host "The FPSAbove value must be greater than the FPSBelow value." -ForegroundColor Green
        Break
    }

    # Ensure a fresh configuration is retrieved
    Clear-VmsCache

    $badPracticeCameraSettings = New-Object System.Collections.Generic.List[PSCustomObject]
    $recs = Get-VmsRecordingServer

    $recProcessed = 0
    foreach ($rec in $recs)
    {
        $svc = $rec | Get-RecorderStatusService2
        $hwProcessed = 0
        $hardwares = Get-VmsHardware -RecordingServer $rec | Where-Object Enabled
        Write-Progress -Activity "Gathering information for Recording Server #$($recProcessed + 1) of $($recs.Count)" -Id 1 -PercentComplete ($recProcessed / $recs.Count * 100)
        foreach ($hw in $hardwares)
        {
            Write-Progress -Activity "Gathering information for hardware #$($hwProcessed + 1) of $($hardwares.Count)" -Id 2 -ParentId 1 -PercentComplete ($hwProcessed / $hardwares.Count * 100)
            $badHardwareSetting = $false
            # Check if camera supports HTTPS and, if so, is it enabled
            $hwSettings = $hw | Get-HardwareSetting
            if ($null -eq $hwSettings.HTTPSEnabled) {
                $httpsSupported = $false
                $httpsEnabled = $null
                $badHardwareSetting = $true
            } elseif ($hwSettings.HTTPSEnabled -eq 'no') {
                $httpsSupported = $null
                $httpsEnabled = $false
                $badHardwareSetting = $true
            } else {
                $httpsSupported = $null
                $httpsEnabled = $null
            }

            $camProcessed = 0
            $cameras = Get-VmsCamera -Hardware $hw
            foreach ($cam in $cameras)
            {
                Write-Progress -Activity "Gathering information for camera #$($camProcessed + 1) of $($cameras.Count)" -Id 3 -ParentId 2 -PercentComplete ($camProcessed / $cameras.Count * 100)
                $badCameraSetting = $false
                $motionSettings = $cam.MotionDetectionFolder.MotionDetections

                # Check if Generate Motion Metadata is disabled
                $generateMotionMetadata = $null
                if ($motionSettings.GenerateMotionMetadata -eq $false)
                {
                    $generateMotionMetadata = $motionSettings.GenerateMotionMetadata
                    $badCameraSetting = $true
                }

                # Check if Hardware Accelerated Motion is set to Off
                $hardwareAcceleratedMotion = $null
                if ($motionSettings.HardwareAccelerationMode -eq "Off")
                {
                    $hardwareAcceleratedMotion = $motionSettings.HardwareAccelerationMode
                    $badCameraSetting = $true
                }

                # Check if "Detection resolution" is set to Optimized (25%) or Normal (100%) instead of Fast (12%)
                $motionDetectionResolution = $null
                if ($motionSettings.DetectionMethod -ne "Fast")
                {
                    switch ($motionSettings.DetectionMethod)
                    {
                        Optimized {$motionDetectionResolution = "25% --> 12%"}
                        Normal {$motionDetectionResolution = "100% --> 12%"}
                    }
                    $badCameraSetting = $true
                }

                # We need to get the stream number for the Record stream
                # This cycles through until we find the stream number that is set for Record
                $recordedStream = 0
                $streamsInfo = $cam.StreamFolder.Streams.StreamUsageChildItems
                foreach ($stream in $streamsInfo)
                {
                    if ($stream.Record -eq $true)
                    {
                        Break
                    }
                    $recordedStream++
                }

                $streams = $cam | Get-VmsCameraStream -RawValues
                $recordingStreamValues = $streams | Where-Object {$_.Recorded -eq $true -and $_.PlaybackDefault -eq $true}
                $keyframesOnly = $motionSettings.KeyframesOnly
                $maxGOPMode = $recordingStreamValues.Settings.MaxGOPMode
                $zipstreamGOPMode = $recordingStreamValues.Settings.ZGopMode

                # Check if motion on keyframes only is disabled and GOP mode is set to "default"
                $allFramesDefaultGOP = $null
                if ($keyframesOnly -eq $false -and $maxGOPMode -eq "default")
                {
                    $allFramesDefaultGOP = $true
                    $badCameraSetting = $true
                }

                # Check if motion on keyframes only is enabled and GOP mode is set to "custom"
                $keyframesCustomGOP = $null
                if ($keyframesOnly -eq $true -and $maxGOPMode -eq "custom")
                {
                    $keyframesCustomGOP = $true
                    $badCameraSetting = $true
                }

                # Check if motion on keyframes only is disabled and Zipstream GOP Mode is set to Fixed
                $allFramesZipstreamFixedGOP = $null
                if ($keyframesOnly -eq $false -and $zipstreamGOPMode -eq "fixed")
                {
                    $allFramesZipstreamFixedGOP = $true
                    $badCameraSetting = $true
                }

                # Check if motion on keyframes only is enabled and Zipstream GOP Mode is set to Dynamic
                $keyframesZipstreamDynamicGOP = $null
                if ($keyframesOnly -eq $true -and $zipstreamGOPMode -eq "dynamic")
                {
                    $keyframesZipstreamDynamicGOP = $true
                    $badCameraSetting = $true
                }

                $camStat = $svc.GetVideoDeviceStatistics((Get-VmsToken),$cam.Id)
                $streamStats = $camStat.VideoStreamStatisticsArray

                # Check if frame rate of any enabled stream is above, below, or equal to a set value
                if ($hw.Model -notlike "Universal*" -and $hw.Model -notlike "*StableFPS*" -and $hw.Model -notlike "*VideoPush*" -and ($null -ne $FPSAbove -or $null -ne $FPSBelow -or $null -ne $FPSNotEqualTo))
                {
                    $FramerateAbove = $null
                    $FramerateBelow = $null
                    $FramerateNotEqualTo = $null
                    $framerate = $null

                    if ($streamStats.Count -gt 0)
                    {
                        foreach ($streamStat in $streamStats)
                        {
                            if (-not [double]::IsNaN($streamStat.FPSRequested))
                            {
                                $framerate = [math]::Round($streamStat.FPSRequested,0)
                            } elseif (-not [double]::IsNaN($streamStat.FPS))
                            {
                                $framerate = [math]::Round($streamStat.FPS,0)
                            } else
                            {
                                $framerate = $null
                            }

                            if ($null -ne $FPSAbove -and $framerate -gt $FPSAbove)
                            {
                                [string]$FramerateAbove = $framerate
                                $badCameraSetting = $true
                            } elseif ($null -ne $FPSAbove -and $null -eq $framerate)
                            {
                                $FramerateAbove = "No framerate data available"
                                $badCameraSetting = $true
                            }

                            if ($null -ne $FPSBelow -and $framerate -lt $FPSBelow)
                            {
                                [string]$FramerateBelow = $framerate
                                $badCameraSetting = $true
                            } elseif ($null -ne $FPSBelow -and $null -eq $framerate)
                            {
                                $FramerateBelow = "No framerate data available"
                                $badCameraSetting = $true
                            }

                            if ($null -ne $FPSNotEqualTo -and $framerate -ne $FPSNotEqualTo)
                            {
                                [string]$FramerateNotEqualTo = $framerate
                                $badCameraSetting = $true
                            } elseif ($null -ne $FPSNotEqualTo -and $null -eq $framerate)
                            {
                                $FramerateNotEqualTo = "No framerate data available"
                                $badCameraSetting = $true
                            }
                        }
                    } else
                    {
                        for ($i=0;$i -lt $streams.Length;$i++)
                        {
                            $streamSetting = $streams[$i].Settings
                            if ([string]::IsNullOrEmpty($streamSetting.FPS) -eq $false)
                            {
                                $framerate = [math]::Round($streamSetting.FPS,0)
                            } elseif ([string]::IsNullOrEmpty($streamSetting.Framerate) -eq $false)
                            {
                                $framerate = [math]::Round($streamSetting.Framerate,0)
                            } else
                            {
                                $framerate = $null
                            }

                            if ($null -ne $FPSAbove -and $framerate -gt $FPSAbove)
                            {
                                [string]$FramerateAbove = $framerate
                                $badCameraSetting = $true
                            } elseif ($null -ne $FPSAbove -and $null -eq $framerate)
                            {
                                $FramerateAbove = "No framerate data available"
                                $badCameraSetting = $true
                            }

                            if ($null -ne $FPSBelow -and $framerate -lt $FPSBelow)
                            {
                                [string]$FramerateBelow = $framerate
                                $badCameraSetting = $true
                            } elseif ($null -ne $FPSBelow -and $null -eq $framerate)
                            {
                                $FramerateBelow = "No framerate data available"
                                $badCameraSetting = $true
                            }

                            if ($null -ne $FPSNotEqualTo -and $framerate -gt $FPSNotEqualTo)
                            {
                                [string]$FramerateNotEqualTo = $framerate
                                $badCameraSetting = $true
                            } elseif ($null -ne $FPSNotEqualTo -and $null -eq $framerate)
                            {
                                $FramerateNotEqualTo = "No framerate data available"
                                $badCameraSetting = $true
                            }
                        }
                    }
                }

                # Compare current recorded resolution to max available resolution to make sure max resolution is recorded
                $currentResolution = $recordingStreamValues.Settings.Resolution
                if ($null -ne $currentResolution -and $currentResolution -match "\dx\d" -and $hw.Model -notlike "Universal*" -and $hw.Model -notlike "*StableFPS*" -and $hw.Model -notlike "*VideoPush*")
                {
                    $currentIndexOfX = $currentResolution.IndexOf("x")
                    $currentWidth = [int]$currentResolution.Substring(0,$currentIndexOfX)
                    $currentHeight = $currentResolution.Substring($currentIndexOfX + 1,$currentResolution.Length - $currentIndexOfX - 1)
                    $currentPixelQty = $currentWidth * $currentHeight
                    $resolutions = $recordingStreamValues.ValueTypeInfo.Resolution
                    foreach ($resolution in $resolutions.Value)
                    {
                        $indexOfX = $resolution.IndexOf("x")
                        $width = [int]$resolution.Substring(0,$indexOfX)
                        $height = [int]$resolution.Substring($indexOfX + 1,$resolution.Length - $indexOfX - 1)
                        $pixelQty = $width * $height

                        $maxResolutionForRecording = $null
                        if ($pixelQty -gt $currentPixelQty)
                        {
                            $maxResolutionForRecording = "$($currentResolution) --> $($resolution)"
                            $badCameraSetting = $true
                            Break
                        }
                    }
                }

                # Check if the recording codec is set to the most efficient codec available.
                # Note that h.264 and h.265 are considered equally as efficient for the time being.
                if ($hw.Model -notlike "Universal*" -and $hw.Model -notlike "*StableFPS*" -and $hw.Model -notlike "*VideoPush*")
                {
                    $availableCodecs = $recordingStreamValues.ValueTypeInfo.Codec
                    if ([string]::IsNullOrEmpty($availableCodecs))
                    {
                        $bestRecordingCodec = "No codec data available"
                        $badCameraSetting = $true
                    }

                    if ($recordingStreamValues.Settings.Codec -match "^\d+$" -eq $false)
                    {
                        $codec = $recordingStreamValues.Settings.Codec
                    } else
                    {
                        switch ($recordingStreamValues.Settings.Codec)
                        {
                            '0' {$codec = 'MJPEG'; break}
                            '1' {$codec = 'MPEG4'; break}
                            '2' {$codec = 'MPEG4'; break}
                            '3' {$codec = 'H264'; break}
                            '4' {$codec = 'H264'; break}
                            '5' {$codec = 'H264'; break}
                            '6' {$codec = 'H264'; break}
                            '7' {$codec = 'H265'; break}
                            '8' {$codec = 'H265'; break}
                        }
                    }

                    switch ($codec)
                    {
                        h265 {$recordingCodec = 1}
                        h264 {$recordingCodec = 1}
                        mpeg4 {$recordingCodec = 3}
                        jpeg {$recordingCodec = 4}
                        mjpeg {$recordingCodec = 4}
                        Default {$recordingCodec = -1}
                    }

                    foreach ($availableCodec in $availableCodecs)
                    {
                        switch ($availableCodec.Value)
                        {
                            '8' {$availableCodec.Value = 'H265'; break}
                            '7' {$availableCodec.Value = 'H265'; break}
                            '6' {$availableCodec.Value = 'H264'; break}
                            '5' {$availableCodec.Value = 'H264'; break}
                            '4' {$availableCodec.Value = 'H264'; break}
                            '3' {$availableCodec.Value = 'H264'; break}
                            '2' {$availableCodec.Value = 'MPEG4'; break}
                            '1' {$availableCodec.Value = 'MPEG4'; break}
                            '0' {$availableCodec.Value = 'MJPEG'; break}
                        }

                        switch ($availableCodec.Value)
                        {
                            h265 {$codecType = 1}
                            h264 {$codecType = 1}
                            mpeg4 {$codecType = 3}
                            jpeg {$codecType = 4}
                            mjpeg {$codecType = 4}
                            Default {$codecType = -1}
                        }

                        $bestRecordingCodec = $null
                        if ($recordingCodec -gt $codecType)
                        {
                            $bestRecordingCodec = "$($codec) --> $($availableCodec.Value)"
                            $badCameraSetting = $true
                            Break
                        }
                    }
                }

                # If Corporate or Expert, check if there is at least two streams configured so Adaptive streaming can be used
                if ((Get-LicenseInfo).DisplayName -like "*Corporate*" -or (Get-LicenseInfo).DisplayName -like "*Expert*" -and $hw.Model -notlike "Universal*" -and $hw.Model -notlike "*StableFPS*" -and $hw.Model -notlike "*VideoPush*")
                {
                    $adaptiveStreaming = $null
                    if (($streams | Where-Object Enabled).Count -lt 2 -and $streamStats.Count -lt 2)
                    {
                        $adaptiveStreaming = $false
                        $badCameraSetting = $true
                    }
                }

                if ($badHardwareSetting -eq $true -or $badCameraSetting -eq $true)
                {
                    $row = [PSCustomObject]@{
                        "RecordingServer" = $rec.Name
                        "HardwareName" = $hw.Name
                        "HTTPS_Supported" = $httpsSupported
                        "HTTPS_Enabled" = $httpsEnabled
                        "CameraName" = $cam.Name
                        "VMDAllFrames - DefaultGOP" = $allFramesDefaultGOP
                        "KeyframesVMD - CustomGOP" = $keyframesCustomGOP
                        "VMDAllFrames - ZipstreamFixedGOP" = $allFramesZipstreamFixedGOP
                        "KeyframesVMD - ZipstreamDynamicGOP" = $keyframesZipstreamDynamicGOP
                        "MotionDetectionResolution" = $motionDetectionResolution
                        "GenerateMotionMetadata" = $generateMotionMetadata
                        "HardwareAcceleratedMotion" = $hardwareAcceleratedMotion
                        "FPSAbove$($FPSAbove)" = $FramerateAbove
                        "FPSBelow$($FPSBelow)" = $FramerateBelow
                        "FPSNotEqualTo$($FPSNotEqualTo)" = $FramerateNotEqualTo
                        "BestRecordingCodec" = $bestRecordingCodec
                        "MaxResolutionForRecording" = $maxResolutionForRecording
                        "AdaptiveStreaming" = $adaptiveStreaming
                    }
                    $badPracticeCameraSettings.Add($row)
                }
                Write-Progress -Activity "Gathering information for camera #$($camProcessed + 1) of $($cameras.Count)" -Id 3 -ParentId 2 -PercentComplete ($camProcessed / $cameras.Count * 100)
                $camProcessed++
            }
            Write-Progress -Activity "Gathering information for hardware #$($hwProcessed + 1) of $($hardwares.Count)" -Id 2 -ParentId 1 -PercentComplete ($hwProcessed / $hardwares.Count * 100)
            $hwProcessed++
        }
        Write-Progress -Activity "Gathering information for Recording Server #$($recProcessed + 1) of $($recs.Count)" -Id 1 -PercentComplete ($recProcessed / $recs.Count * 100)
        $recProcessed++
    }
    $badPracticeCameraSettings
}