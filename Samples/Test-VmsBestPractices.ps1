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
         - Recording stream not set to best codec (e.g., set to MJPEG when h.264 is available)
         - Record stream not set to highest resolution
        
        Checking the resolution and codec does not work on all cameras due to how some cameras display that information.

    .EXAMPLE
        Get-NonDefaultCameraSettings

        Creates a report of any cameras that have a non-default setting
    #>

    $badPracticeCameraSettings = New-Object System.Collections.Generic.List[PSCustomObject]

    foreach ($rec in Get-RecordingServer)
    {
        foreach ($hw in $rec | Get-Hardware | Where-Object Enabled)
        {
            $hwSetting = $hw | Get-HardwareSetting
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
                
                # We need to get the stream number for the Record stream
                # This cycles through until we find the stream number that is set for Record
                $recordedStream = 0
                $streams = $cam.StreamFolder.Streams.streamusagechilditems
                foreach ($stream in $streams)
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

                # Compare current recorded resolution to max available resolution to make sure max resolution is recorded
                $currentResolution = $recordingStreamSettings.Resolution
                if ($null -ne $currentResolution -and $currentResolution -match "\dx\d")
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
                            $maxResolutionForRecording = $false
                            $badSetting = $true
                            Break
                        }
                    }
                }

                # Check if the recording codec is set to the most efficient codec available
                if ($hwSetting.ProductID -notlike "Universal*")
                {
                    $availableCodecs = $cam | Get-CameraSetting -Stream -StreamNumber $recordedStream -Name Codec -ValueTypeInfo

                    switch ($recordingStreamSettings.Codec)
                    {
                        h265 {$recordingCodec = 1}
                        h264 {$recordingCodec = 2}
                        mpeg4 {$recordingCodec = 3}
                        jpeg {$recordingCodec = 4}
                        Default {$recordingCodec = -1}
                    }

                    foreach ($codec in $availableCodecs)
                    {
                        switch ($codec.Value)
                        {
                            h265 {$codecType = 1}
                            h264 {$codecType = 2}
                            mpeg4 {$codecType = 3}
                            jpeg {$codecType = 4}
                            mjpeg {$codecType = 4}
                            Default {$codecType = -1}
                        }

                        $bestRecordingCodec = $null
                        if ($recordingCodec -gt $codecType)
                        {
                            $bestRecordingCodec = $false
                            $badSetting = $true
                            Break
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
                            'GenerateMotionMetadata' = $generateMotionMetadata
                            'HardwareAcceleratedMotion' = $hardwareAcceleratedMotion
                            'BestRecordingCodec' = $bestRecordingCodec
                            'MaxResolutionForRecording' = $maxResolutionForRecording
                        }
                        $badPracticeCameraSettings.Add($row)
                    }
                }
            }
        }
    }
    $badPracticeCameraSettings
}