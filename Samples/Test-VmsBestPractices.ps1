function Test-VmsBestPractices
{
    <#
    .SYNOPSIS
        Finds cameras that have non-default settings that may affect performance or function.

    .DESCRIPTION
        Finds cameras that have any of the following settings:
         - Motion on keyframes disabled unless custom GOP or Dynamic GOP is enabled
         - Custom GOP on record stream unless Motion on keyframes is disabled
         - Dynamic GOP on record stream on Axis cameras unless Motion on keyframes is disabled
         - Hardware acceleration for motion detection disabled
         - Generate motion data for Smart Search disabled
         - Flag if framerate on any stream is higher than 15fps
         - Recording stream not set to best codec (e.g., set to MJPEG when h.264 is available)
         - Record stream not set to highest resolution
         - If using Expert or Corporate, cameras not having more than one stream configured so that Adaptive Streaming can be used.

        Checking the resolution and codec does not work on all cameras due to how some cameras display that information.

    .EXAMPLE
        Test-VmsBestPractices

        Creates a report of any cameras that have settings that are considered not best practices
    #>

    $badPracticeCameraSettings = New-Object System.Collections.Generic.List[PSCustomObject]

    foreach ($rec in Get-RecordingServer)
    {
        foreach ($hw in $rec | Get-Hardware | Where-Object Enabled)
        {
            foreach ($cam in $hw | Get-Camera | Where-Object Enabled)
            {
                $badSetting = $false
                $motionSettings = $cam.MotionDetectionFolder.MotionDetections

                # Check if Generate Motion Metadata is disabled
                $generateMotionMetadata = $null
                if ($motionSettings.GenerateMotionMetadata -eq $false)
                {
                    $generateMotionMetadata = $motionSettings.GenerateMotionMetadata
                    $badSetting = $true
                }

                # Check if Hardware Accelerated Motion is set to Off
                $hardwareAcceleratedMotion = $null
                if ($motionSettings.HardwareAccelerationMode -eq "Off")
                {
                    $hardwareAcceleratedMotion = $motionSettings.HardwareAccelerationMode
                    $badSetting = $true
                }

                # Check if "Detection resolution" is set to Optimized (25%) or Normal (100%) instead of Fast (12%)
                $motionDetectionResolution = $null
                if ($motionSettings.DetectionMethod -ne "Fast")
                {
                    switch ($motionSettings.DetectionMethod)
                    {
                        Optimized {$hardwareAcceleratedMotion = "25% --> 12%"}
                        Normal {$hardwareAcceleratedMotion = "100% --> 12%"}
                    }
                    $badSetting = $true
                }

                # We need to get the stream number for the Record stream
                # This cycles through until we find the stream number that is set for Record
                $recordedStream = 0
                $streamsInfo = $cam.StreamFolder.Streams.streamusagechilditems
                foreach ($stream in $streamsInfo)
                {
                    if ($stream.Record -eq $true)
                    {
                        Break
                    }
                    $recordedStream++
                }

                $recordingStreamSettings = $cam | Get-CameraSetting -Stream -StreamNumber $recordedStream
                $keyframesOnly = $motionSettings.KeyframesOnly
                $maxGOPMode = $recordingStreamSettings.maxGOPMode
                $zipstreamGOPMode = $recordingStreamSettings.ZGopMode

                # Check if motion on keyframes only is disabled and GOP mode is set to "default"
                $allFramesDefaultGOP = $null
                if ($keyframesOnly -eq $false -and $maxGOPMode -eq "default")
                {
                    $allFramesDefaultGOP = $true
                    $badSetting = $true
                }

                # Check if motion on keyframes only is enabled and GOP mode is set to "custom"
                $keyframesCustomGOP = $null
                if ($keyframesOnly -eq $true -and $maxGOPMode -eq "custom")
                {
                    $keyframesCustomGOP = $true
                    $badSetting = $true
                }

                # Check if motion on keyframes only is disabled and Zipstream GOP Mode is set to Fixed
                $allFramesZipstreamFixedGOP = $null
                if ($keyframesOnly -eq $false -and $zipstreamGOPMode -eq "fixed")
                {
                    $allFramesZipstreamFixedGOP = $true
                    $badSetting = $true
                }

                # Check if motion on keyframes only is enabled and Zipstream GOP Mode is set to Dynamic
                $keyframesZipstreamDynamicGOP = $null
                if ($keyframesOnly -eq $true -and $zipstreamGOPMode -eq "dynamic")
                {
                    $keyframesZipstreamDynamicGOP = $true
                    $badSetting = $true
                }

                # Check if frame rate is set above 15fps
                if ($hw.Model -notlike "Universal*" -and $hw.Model -notlike "*StableFPS*" -and $hw.Model -notlike "*VideoPush*")
                {
                    $framerateAbove15FPS = $null
                    $streams = $cam | Get-Stream -All
                    for ($i=0;$i -lt $streams.length;$i++)
                    {
                        $streamSetting = $cam | Get-CameraSetting -Stream -StreamNumber $i
                        $fps = [math]::Round($streamSetting.FPS,0)
                        $framerate = [math]::Round($streamSetting.Framerate,0)
                        if ([string]::IsNullOrEmpty($streamSetting.FPS -and [string]::IsNullOrEmpty($streamSetting.Framerate)))
                        {
                            $framerateAbove15FPS = "No framerate data available"
                            $badSetting = $true
                        } elseif ($fps -gt 15 -or $framerate -gt 15)
                        {
                            $framerateAbove15FPS = $true
                            $badSetting = $true
                        }
                    }
                }

                # Compare current recorded resolution to max available resolution to make sure max resolution is recorded
                $currentResolution = $recordingStreamSettings.Resolution
                if ($null -ne $currentResolution -and $currentResolution -match "\dx\d" -and $hw.Model -notlike "Universal*" -and $hw.Model -notlike "*StableFPS*" -and $hw.Model -notlike "*VideoPush*")
                {
                    $currentIndexOfX = $currentResolution.IndexOf("x")
                    $currentWidth = [int]$currentResolution.Substring(0,$currentIndexOfX)
                    $currentHeight = $currentResolution.Substring($currentIndexOfX + 1,$currentResolution.length - $currentIndexOfX - 1)
                    $currentPixelQty = $currentWidth * $currentHeight
                    $resolutions = $cam | Get-CameraSetting -Stream -StreamNumber $recordedStream -Name Resolution -ValueTypeInfo
                    foreach ($resolution in $resolutions.Value)
                    {
                        $indexOfX = $resolution.IndexOf("x")
                        $width = [int]$resolution.Substring(0,$indexOfX)
                        $height = [int]$resolution.Substring($indexOfX + 1,$resolution.length - $indexOfX - 1)
                        $pixelQty = $width * $height

                        $maxResolutionForRecording = $null
                        if ($pixelQty -gt $currentPixelQty)
                        {
                            $maxResolutionForRecording = "$($currentResolution) --> $($resolution)"
                            $badSetting = $true
                            Break
                        }
                    }
                }

                # Check if the recording codec is set to the most efficient codec available.
                # Note that h.264 and h.265 are considered equally as efficient for the time being.
                if ($hw.Model -notlike "Universal*" -and $hw.Model -notlike "*StableFPS*" -and $hw.Model -notlike "*VideoPush*")
                {
                    $availableCodecs = $cam | Get-CameraSetting -Stream -StreamNumber $recordedStream -Name Codec -ValueTypeInfo
                    if ([string]::IsNullOrEmpty($availableCodecs))
                    {
                        $bestRecordingCodec = "No codec data available"
                        $badSetting = $true
                    }

                    if ($recordingStreamSettings.Codec -match "^\d+$" -eq $false)
                    {
                        $codec = $recordingStreamSettings.Codec
                    } else
                    {
                        switch ($recordingStreamSettings.Codec)
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
                            $badSetting = $true
                            Break
                        }
                    }
                }

                # If Corporate or Expert, check if there is at least two streams configured so Adaptive streaming can be used
                if ((Get-LicenseInfo).DisplayName -like "*Corporate*" -or (Get-LicenseInfo).DisplayName -like "*Expert*" -and $hw.Model -notlike "Universal*" -and $hw.Model -notlike "*StableFPS*" -and $hw.Model -notlike "*VideoPush*")
                {
                    $adaptiveStreaming = $null
                    if ($streams.count -lt 2)
                    {
                        $adaptiveStreaming = $false
                        $badSetting = $true
                    }
                }

                if ($badSetting -eq $true)
                {
                    $row = [PSCustomObject]@{
                        'RecordingServer' = $rec.Name
                        'HardwareName' = $hw.Name
                        'CameraName' = $cam.Name
                        'VMDAllFrames - DefaultGOP' = $allFramesDefaultGOP
                        'KeyframesVMD - CustomGOP' = $keyframesCustomGOP
                        'VMDAllFrames - ZipstreamFixedGOP' = $allFramesZipstreamFixedGOP
                        'KeyframesVMD - ZipstreamDynamicGOP' = $keyframesZipstreamDynamicGOP
                        'MotionDetectionResolution' = $motionDetectionResolution
                        'GenerateMotionMetadata' = $generateMotionMetadata
                        'HardwareAcceleratedMotion' = $hardwareAcceleratedMotion
                        'FPSAbove15' = $framerateAbove15FPS
                        'BestRecordingCodec' = $bestRecordingCodec
                        'MaxResolutionForRecording' = $maxResolutionForRecording
                        'AdaptiveStreaming' = $adaptiveStreaming
                    }
                    $badPracticeCameraSettings.Add($row)
                }
            }
        }
    }
    $badPracticeCameraSettings
}