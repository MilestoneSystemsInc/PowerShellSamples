function GetCodecValueFromStream {
    param([VideoOS.Platform.ConfigurationItems.StreamChildItem]$Stream)

    $res = $Stream.Properties.GetValue("Codec")
    if ($null -ne $res) {
        ($Stream.Properties.GetValueTypeInfoCollection("Codec") | Where-Object Value -eq $res).Name
        return
    }
}

function GetFpsValueFromStream {
    param([VideoOS.Platform.ConfigurationItems.StreamChildItem]$Stream)

    $res = $Stream.Properties.GetValue("FPS")
    if ($null -ne $res) {
        $val = ($Stream.Properties.GetValueTypeInfoCollection("FPS") | Where-Object Value -eq $res).Name
        if ($null -eq $val) {
            $res
        }
        else {
            $val
        }
        return
    }

    $res = $Stream.Properties.GetValue("Framerate")
    if ($null -ne $res) {
        $val = ($Stream.Properties.GetValueTypeInfoCollection("Framerate") | Where-Object Value -eq $res).Name
        if ($null -eq $val) {
            $res
        }
        else {
            $val
        }
        return
    }
}

function GetResolutionValueFromStream {
    param([VideoOS.Platform.ConfigurationItems.StreamChildItem]$Stream)

    $res = $Stream.Properties.GetValue("StreamProperty")
    if ($null -ne $res) {
        ($Stream.Properties.GetValueTypeInfoCollection("StreamProperty") | Where-Object Value -eq $res).Name
        return
    }

    $res = $Stream.Properties.GetValue("Resolution")
    if ($null -ne $res) {
        ($Stream.Properties.GetValueTypeInfoCollection("Resolution") | Where-Object Value -eq $res).Name
        return
    }
}

function Get-CameraReport2 {
	<#
    .SYNOPSIS
        Gets a detailed report containing information about all cameras on one or more Recording Servers

    .DESCRIPTION
        Gets a [PSCustomObject] with a wide range of properties for each camera found on one or more
		Recording Servers. When the -RecordingServer parameter is omitted, all cameras on all servers in
		the currently selected site will be included in the report. Otherwise, only the server(s) included
		in the -RecordingServer array will enumerated for cameras to include in the report.

        A number of switches can optionally be included to add information to the default result set. For
		example, camera passwords are only included when the -IncludePasswords switch is present.

    .PARAMETER RecordingServer
        Specifies one Recording Server, or an array of Recording Servers. All cameras on the specified
		servers will be included in the report. If omitted, all cameras from all Recording Servers on the
		currently selected site will be included in the report. To include only cameras from a subset of
		Recording Servers, use Get-RecordingServer to select and filter for the desired servers.

    .PARAMETER IncludeActualResolutions
        When this switch is present, a live and playback image will be requested from the Recording Server
		for every enabled camera in the report. The resolution in the format WidthxHeight for a single image
		will be included columns named ActualLiveResolution and ActualRecordingResolution.

	.PARAMETER IncludeDisabledCameras
        Disabled cameras, which are considered to be any camera where either the camera, or it's parent
		Hardware object are disabled in Milestone, are excluded from the report by default. To include
		properties from disabled cameras in addition to enabled cameras, you must supply this switch.

		For disabled cameras, we will not attempt to retrieve the Actual*Resolution values or the first
		and last image timestamps from the media database.

	.PARAMETER IncludePasswords
        Passwords are only included in the report when this switch is present. Otherwise, only the UserName
		value will be included.

	.PARAMETER IncludePlaybackInfo
        When present, the IncludePlaybackInfo switch will cause the Get-PlaybackInfo command to be executed
		on each enabled camera and the first and last image timestamps from the media database will be
		included in the report.

	.PARAMETER AdditionalHardwareProperties
        Specifies an array of setting keys which should be included as columns in the report. The available
		keys vary by hardware driver. You can discover the available columns using the Get-HardwareSetting
		command.

	.PARAMETER AdditionalCameraProperties
        Specifies an array of setting keys which should be included as columns in the report. The available
		keys vary by hardware driver. You can discover the available columns using the Get-CameraSetting -General
		command.

    .EXAMPLE
        Get-RecordingServer -Name NVR01 | Get-CameraReport -IncludePasswords -AdditionalHardwareProperties HTTPSEnabled

        Generates a report including all cameras on NVR01, and the report will include hardware passwords, and the
		HTTPSEnabled value for all hardware devices which have this setting available.
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        [VideoOS.Platform.ConfigurationItems.RecordingServer[]]
        $RecordingServer,
        [Parameter()]
        [switch]
        $IncludeActualResolutions,
        [Parameter()]
        [switch]
        $IncludeDisabledCameras,
        [Parameter()]
        [switch]
        $IncludePasswords,
        [Parameter()]
        [switch]
        $IncludePlaybackInfo,
        [Parameter()]
        [string[]]
        $AdditionalHardwareProperties,
        # Additional camera setting values to retrieve using exact key names
        [Parameter()]
        [string[]]
        $AdditionalCameraProperties
    )

    process {
        $states = Get-ItemState -CamerasOnly
        $RecordingServer = if ($null -eq $RecordingServer) { Get-RecordingServer } else { $RecordingServer }
        foreach ($rec in $RecordingServer) {
            foreach ($hw in $rec | Get-Hardware) {
                if ($hw.Enabled -or $IncludeDisabledCameras) {
                    $driver = $hw | Get-HardwareDriver
                    $hwSettings = $hw | Get-HardwareSetting
                    $pass = if ($IncludePasswords) { $hw | Get-HardwarePassword } else { $null }
                }
                foreach ($cam in $hw | Get-Camera) {
                    $enabled = $hw.Enabled -and $cam.Enabled
                    if (-not $enabled -and -not $IncludeDisabledCameras) { continue }
                    $camSettings = $cam | Get-CameraSetting -General

                    $liveSize = $null
                    $playbackSize = $null
                    if ($enabled -and $IncludeActualResolutions) {
                        $live = $cam | Get-Snapshot -Live -LiveTimeoutMS 10000
                        $playback = $cam | Get-Snapshot -Behavior GetEnd
                        $liveSize = if ($null -ne $live.Content -and $live.Content.Length -gt 0) { "$($live.Width)x$($live.Height)" } else { $null }
                        $playbackSize = if ($null -ne $playback.Bytes -and $playback.Bytes.Length -gt 0) { "$($playback.Width)x$($playback.Height)" } else { $null }
                    }


                    $liveStream = $cam | Get-Stream -LiveDefault
                    $recordedStream = $cam | Get-Stream -Recorded
                    $liveStreamName = $liveStream.StreamReferenceIdValues.Keys | ForEach-Object { if ($liveStream.StreamReferenceId -eq $liveStream.StreamReferenceIdValues[$_]) { $_ } }
                    $recordedStreamName = $recordedStream.StreamReferenceIdValues.Keys | ForEach-Object { if ($recordedStream.StreamReferenceId -eq $recordedStream.StreamReferenceIdValues[$_]) { $_ } }
                    $liveStreamSettings = $cam.DeviceDriverSettingsFolder.DeviceDriverSettings[0].StreamChildItems | Where-Object DisplayName -eq $liveStreamName
                    $recordedStreamSettings = $cam.DeviceDriverSettingsFolder.DeviceDriverSettings[0].StreamChildItems | Where-Object DisplayName -eq $recordedStreamName
                    $motion = $cam.MotionDetectionFolder.MotionDetections[0]
                    $storage = $rec.StorageFolder.Storages | Where-Object Path -eq $cam.RecordingStorage
                    
                    $obj = [PSCustomObject]@{
                        CameraName = $cam.Name
                        Channel = $cam.Channel
                        Enabled = $hw.Enabled -and $cam.Enabled
                        State = ($states | Where-Object { $_.FQID.ObjectId -eq $cam.Id }).State
                        LastModified = $cam.LastModified
                        CameraId = $cam.Id
                        HardwareName = $hw.Name
                        HardwareId = $hw.Id
                        RecorderName = $rec.Name
                        RecorderHostName = $rec.HostName
                        RecorderId = $rec.Id
                        Model = $hw.Model
                        Driver = $driver.Name
                        Address = $hw.Address
                        UserName = $hw.UserName
                        Password = $pass
                        MAC = $hwSettings.MacAddress
                        
                        LiveStream = $liveStreamName
                        LiveCodec = GetCodecValueFromStream $liveStreamSettings
                        LiveResolution = GetResolutionValueFromStream $liveStreamSettings
                        LiveFPS = GetFpsValueFromStream $liveStreamSettings
                        
                        RecordingStream = $recordedStreamName
                        RecordingCodec = GetCodecValueFromStream $recordedStreamSettings
                        RecordingResolution = GetResolutionValueFromStream $recordedStreamSettings
                        RecordingFPS = GetFpsValueFromStream $recordedStreamSettings
                        
                        ActualLiveResolution = $liveSize
                        ActualRecordingResolution = $playbackSize
                        
                        RecordingEnabled = $cam.RecordingEnabled
                        RecordKeyframesOnly = $cam.RecordKeyframesOnly
                        PreBufferEnabled = $cam.PrebufferEnabled
                        PreBufferSeconds = $cam.PrebufferSeconds
                        PreBufferInMemory = $cam.PrebufferInMemory
                        StorageName = $storage.Name
                        StoragePath = [IO.Path]::Combine($storage.DiskPath, $storage.Id)
                        
                        MotionEnabled = $motion.Enabled
                        MotionKeyframesOnly = $motion.KeyframesOnly
                        MotionDetectionMethod = $motion.DetectionMethod
                        MotionProcessTime = $motion.ProcessTime
                        MotionManualSensitivity = $motion.ManualSensitivityEnabled
                        MotionMetadataEnabled = $motion.GenerateMotionMetadata
                        MotionHardwareAcceleration = $motion.HardwareAccelerationMode
                    }

                    if ($enabled -and $IncludePlaybackInfo) {
                        try {
                            $info = $cam | Get-PlaybackInfo -ErrorAction Stop
                            $obj | Add-Member -MemberType NoteProperty -Name "OldestImageUtc" -Value $info.Begin
                            $obj | Add-Member -MemberType NoteProperty -Name "LatestImageUtc" -Value $info.End
                        }
                        catch {
                            Write-Warning "Get-PlaybackInfo failed: $($_.Exception.Message)"
                        }
                    }
                    foreach ($p in $AdditionalHardwareProperties) {
                        $obj | Add-Member -MemberType NoteProperty -Name "Custom_$p" -Value $hwSettings.$p
                    }
                    foreach ($p in $AdditionalCameraProperties) {
                        $obj | Add-Member -MemberType NoteProperty -Name "Custom_$p" -Value $camSettings.$p
                    }
                    $obj
                }
            }
        }
    }
}