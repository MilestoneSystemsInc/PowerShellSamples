function Set-AdaptiveStreaming {
    <#
    .SYNOPSIS
        Sets up additional streams for adaptive streaming
    .DESCRIPTION
        Sets up additional streams for adaptive streaming. The first stream gets set at maximum resolution and set as the Primary Record stream.
        Each additional stream gets set at the next lowest resolution that is the same aspect ration as the stream #1.  The last stream
        (which will be the lowest resolution) is set as the default live stream. If -ConfigureAdaptivePlayback (supported on 2023 R2 and newer) is used,
        it will also set the lowest resolution stream of the configured live streams to be the Secondary Record stream and also the default playback stream.

        There will be scenarios where this might create a strange configuration such as setting a JPEG only stream as the record stream or making the the
        lowest resolution stream a JPEG only stream. It is recommended to run a Get-VmsCameraReport to at least check if the Record or Default Live streams
        are configured for MJPEG.
    .EXAMPLE
        Set-AdaptiveStreaming -StreamsPerCamera 3 -FPS 15 -RecordingServerName "*"

        Configures each camera for up to 3 streams (if a camera only supports 2 streams then only two are configured) on all Recording Servers and sets the frame rate to 15
    .EXAMPLE
        Set-AdaptiveStreaming -StreamsPerCamera 1 -RecordingServerName "Milestone-Server"

        Configures each camera for just one stream only on the Recording Server named "Milestone-Server".  This one doesn't set the frame rate.
    .EXAMPLE
        Set-AdaptiveStreaming -StreamsPerCamera 3 -RecordingServerName "*" -CameraName "Front Door Camera"

        Configures 3 streams on a camera named "Front Door Camera"
    .EXAMPLE
        Set-AdaptiveStreaming -StreamsPerCamera 3 -FPS 10 -RecordingServerName "Milestone-Server" -MaxResWidth 3840 -MinResWidth 1921

        All cameras that have a maximum resolution width of 3840 and minimum resolution width of 1921 on Recording Server Milestone-Server will be configured with 3 streams and frame rate of 10.
    .EXAMPLE
        Set-AdaptiveStreaming -StreamsPerCamera 3 -RecordingServerName * -ConfigurAdaptivePlayback

        Configures up to 3 live streams on each camera on each Recording Server. The -ConfigureAdaptivePlayback also configures a secondary recorded stream on the lowest resolution live stream.
    #>

    [CmdletBinding(DefaultParameterSetName='default')]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateRange(1,3)]
        [string]
        $StreamsPerCamera,
        [Parameter(Mandatory=$false)]
        [ValidateRange(1,60)]
        $FPS = $null,
        [Parameter(Mandatory=$true)]
        [string]
        $RecordingServerName,
        [Parameter(Mandatory=$false)]
        [string]
        $CameraName,
        [Parameter(Mandatory=$true,ParameterSetName='ResWidth')]
        $MaxLiveResWidth,
        [Parameter(Mandatory=$true,ParameterSetName='ResWidth')]
        $MinLiveResWidth,
        [Parameter(Mandatory=$false)]
        [switch]
        $ConfigureAdaptivePlayback
    )

    begin
    {
        $ms = Get-VmsManagementServer
        $recs = Get-VmsRecordingServer -Name $RecordingServerName
        if ($ConfigureAdaptivePlayback -and [version]$ms.Version -lt [version]"23.2")
        {
            Write-Warning "Version $($ms.Version) does not support adaptive playback. Please run again without the -ConfigureAdaptivePlayback switch."
            Break
        }

        if ($RecordingServerName -ne "*" -and $recs.Name -notcontains $RecordingServerName)
        {
            Write-Warning "Recording Server does not exist.  Please check spelling and try again."
            Return
        }

        if ($null -ne $CameraName -and $null -eq (Get-VmsCamera -Name $CameraName))
        {
            Write-Warning "Camera does not exist.  Please check spelling and try again."
            Return
        }

        $defaultStreamsPerCamera = $StreamsPerCamera
    }

    process
    {
        Clear-VmsCache
        $svc = Get-IServerCommandService
        $config = $svc.GetConfiguration((Get-Token))
        if ($RecordingServerName -eq "*")
        {
            if ([string]::IsNullOrEmpty($CameraName))
            {
                $camQty = $config.Recorders.Cameras.Count
            } else {
                $camQty = 1
            }
        } else
        {
            if ([string]::IsNullOrEmpty($CameraName))
            {
                $camQty = ($config.Recorders | Where-Object {$_.Name -eq $RecordingServerName}).Cameras.Count
            } else {
                $camQty = 1
            }
        }
        $camProcessed = 1

        if ($null -ne $FPS)
        {
            [decimal]$FPS = $FPS
        }

        foreach ($rec in $recs)
        {
            foreach ($hw in $rec | Get-VmsHardware | Where-Object Enabled)
            {
                foreach ($cam in $hw | Get-VmsCamera -EnableFilter Enable -Name $CameraName)
                {
                    Write-Progress -Activity "Configuring streams for camera $($camProcessed) of $($camQty) (or possibly less)" -PercentComplete ($camProcessed / $camQty * 100)

                    # Get all streams that support a codec other than just JPEG/MJPEG
                    $totalSupportedStreams = $cam | Get-VmsCameraStream -WarningAction SilentlyContinue | Where-Object {$_.ValueTypeInfo.Codec.Value -ne 'JPEG' -and $_.ValueTypeInfo.Codec.Value -ne 'MJPEG'}

                    if ($totalSupportedStreams.Count -eq 0)
                    {
                        Continue
                    } elseif ($totalSupportedStreams.Count -lt $StreamsPerCamera) {
                        $StreamsPerCamera = $totalSupportedStreams.Count
                    } else {
                        $StreamsPerCamera = $defaultStreamsPerCamera
                    }

                    $resolutions = ($cam | Get-VmsCameraStream -WarningAction SilentlyContinue)[0].ValueTypeInfo.Resolution
                    $sortedResolutions = New-Object System.Collections.Generic.List[PSCustomObject]
                    foreach ($resolution in $resolutions.Value)
                    {
                        $resW,$resH = $resolution.Split("x")
                        if ($resW -eq "Auto")
                        {
                            Continue
                        }
                        $megapixel = [int]$resW * [int]$resH
                        $row = [PSCustomObject]@{
                            Resolution = $resolution
                            Megapixel = $megapixel
                        }
                        $sortedResolutions.Add($row)
                    }
                    $resolutions = ($sortedResolutions | Sort-Object -Property Megapixel -Descending).Resolution

                    if ($null -ne $MaxLiveResWidth -and $null -ne $MinLiveResWidth)
                    {
                        if ($resolutions.Split("x")[0] -gt $MaxLiveResWidth -or $resolutions.Split("x")[1] -lt $MinLiveResWidth)
                        {
                            Break
                        }
                    }

                    # If the camera has specific framerate values instead of a range, then we need to choose the framerate
                    # that is closest (but smaller than) to the specified framerate.
                    $newFPS = $FPS
                    $fpsTypes = ($cam | Get-VmsCameraStream -WarningAction SilentlyContinue)[0].ValueTypeInfo.fps
                    if ($null -ne $fpsTypes)
                    {
                        $framerates = $fpsTypes
                    } else
                    {
                        $framerates = ($cam | Get-VmsCameraStream -WarningAction SilentlyContinue)[0].ValueTypeInfo.framerate
                    }

                    if ($framerates.Name -notcontains "MinValue" -and $framerates.Value -notcontains $FPS)
                    {
                        $sortedFramerates = @()
                        foreach ($framerate in $framerates.Value)
                        {
                            $sortedFramerates += [decimal]::Parse($framerate)
                        }

                        $sortedFramerates = $sortedFramerates | Sort-Object

                        $previousFramerate = 0
                        foreach ($framerate in $sortedFramerates)
                        {
                            if ($framerate -gt $FPS)
                            {
                                Write-Warning "$($cam.Name) is not capable of $($newFPS). It will be set to $($previousFramerate)."
                                $newFPS = $previousFramerate
                                Break
                            }
                            $previousFramerate = $framerate
                        }
                    }

                    # If the maximum framerate of the camera is less than the framerate specified, then use the maximum framerate of the camera
                    $maxSupportedFramerate = ($framerates.Value | Measure-Object -Maximum).Maximum
                    if ($newFPS -gt $maxSupportedFramerate -and $null -ne $maxSupportedFramerate)
                    {
                        Write-Warning "$($cam.Name) is not capable of $($newFPS) FPS. It will be set to its max framerate of $($maxSupportedFramerate) FPS."
                        $newFPS = $maxSupportedFramerate

                    }

                    # If there aren't any resolution options, move to the next camera.
                    if ([string]::IsNullOrEmpty($resolutions))
                    {
                        $camProcessed++
                        continue
                    }

                    # Get the max resolution for the first stream
                    $current = (($cam | Get-VmsCameraStream -WarningAction SilentlyContinue)[0].ValueTypeInfo.Resolution | Where-Object {$_.Name -eq ($cam | Get-VmsCameraStream)[0].Settings.Resolution}).Value
                    if ($resolutions.GetType().Name -eq "String")
                    {
                        $max = $resolutions
                    } else
                    {
                        $max = $resolutions[0]
                    }
                    if ('Auto' -eq $max)
                    {
                        $camProcessed++
                        continue
                    }
                    $previousStreamResMP = [int]$max.Split("x")[0] * [int]$max.Split("x")[1]

                    # Get the aspect ratio of the resolution on the first stream
                    $resW,$resH = $max.Split("x")
                    $ratio = $resW / $resH

                    # Set Max Resolution on Stream 1 and set framerate if provided
                    if ($current -ne $resolutions[0].value -and $null -ne $totalSupportedStreams[0].Settings.FPS)
                    {
                        switch($FPS)
                        {
                            $null    {$settings = @{Resolution = $max}}
                            default  {$settings = @{Resolution = $max;FPS = $newFPS}}
                        }
                        $totalSupportedStreams[0] | Set-VmsCameraStream -Settings $settings -WarningAction SilentlyContinue
                    } elseif ($current -ne $resolutions[0].value -and $null -ne $totalSupportedStreams[0].Settings.Framerate) {
                        switch($FPS)
                        {
                            $null    {$settings = @{Resolution = $max}}
                            default  {$settings = @{Resolution = $max;Framerate = $newFPS}}
                        }
                        $totalSupportedStreams[0] | Set-VmsCameraStream -Settings $settings -WarningAction SilentlyContinue
                    } elseif ($current -ne $resolutions[0].value) {
                        $settings = @{
                            Resolution = $max
                        }
                        $totalSupportedStreams[0] | Set-VmsCameraStream -Settings $settings -WarningAction SilentlyContinue
                    }
                    $allStreams = $cam | Get-VmsCameraStream

                    # Disable all streams except for the first one
                    $allStreams[0] | Set-VmsCameraStream -LiveDefault -RecordingTrack Primary
                    for ($i=1;$i -lt $allStreams.length;$i++)
                    {
                        $allStreams[$i] | Set-VmsCameraStream -Disabled
                    }
                    $enabledStreams = $cam | Get-VmsCameraStream -Enabled

                    # Enable additional streams and find appropriate resolution
                    $streamResolution = New-Object System.Collections.Generic.List[PSCustomObject]
                    if ($enabledStreams.length -lt $StreamsPerCamera -and $enabledStreams.length -lt $totalSupportedStreams.Length -and $totalSupportedStreams.length -gt 1)
                    {
                        $extra = 0
                        for ($k=1;$k -lt [int]$StreamsPerCamera+$extra;$k++)
                        {
                            if ((($cam | Get-VmsCameraStream -WarningAction SilentlyContinue)[$k]).Name -match "JPEG")
                            {
                                $extra += 1
                                Continue
                            }
                            $streamValueTypeInfo = ($cam | Get-VmsCameraStream -WarningAction SilentlyContinue)[$k].ValueTypeInfo
                            $codecs = $streamValueTypeInfo.Codec
                            if (($codecs.Value -eq 'MJPEG') -eq $true -or ($codecs.Value -eq 'JPEG') -eq $true )
                            {
                                $extra += 1
                                Continue
                            }
                            $resolutions = $streamValueTypeInfo.Resolution
                            
                            $sortedResolutions = New-Object System.Collections.Generic.List[PSCustomObject]
                            foreach ($resolution in $resolutions)
                            {
                                $resW,$resH = $resolution.Value.Split("x")
                                $megapixel = [int]$resW * [int]$resH
                                $row = [PSCustomObject]@{
                                    Name = $resolution.Name
                                    Resolution = $resolution.Value
                                    Megapixel = $megapixel
                                }
                                $sortedResolutions.Add($row)
                            }
                            $resolutions = $sortedResolutions | Sort-Object -Property Megapixel -Descending

                            # Build Camera Res Array for additional streams
                            $camRes = @()
                            foreach($res in $resolutions)
                            {
                                $aresW,$aresH = $res.Resolution.Split("x")
                                if ($aresW -ne 0 -or $aresH -ne 0)
                                {
                                    $aratio = $aresW / $aresH
                                    $aresW = $aresW -as [int]
                                    if ($aratio -eq $ratio -And $aresW -le 1920 -And $aresW -ge 320 -and ($aresW -ne 1600 -and $aresH -ne 900) -and ($aresW -ne 1024 -and $aresH -ne 576))
                                    {
                                        $camRes += $res
                                    }
                                }
                            }

                            # Enabled additional streams
                            if (-not [string]::IsNullOrEmpty($camRes.Name))
                            {
                                $totalSupportedStreams[$k] | Set-VmsCameraStream -LiveMode WhenNeeded
                                $enabledStreams = $cam | Get-VmsCameraStream -Enabled
                            }

                            foreach ($r in $camRes)
                            {
                                if ($r.Megapixel -lt $previousStreamResMP)
                                {
                                    $row = [PSCustomObject]@{
                                        'Stream' = $enabledStreams[$k]
                                        'Resolution' = $r.Name
                                    }
                                    $streamResolution.Add($row)
                                    Break
                                }
                            }
                            $previousStreamResMP = $r.Megapixel
                        }
                    }

                    foreach ($stream in $streamResolution)
                    {
                        if ($null -ne $stream.stream.Settings.FPS)
                        {
                            switch($FPS)
                            {
                                $null    {$settings = @{Resolution = $stream.Resolution}}
                                default  {$settings = @{Resolution = $stream.Resolution;FPS = $newFPS}}
                            }
                            $stream.Stream | Set-VmsCameraStream -Settings $settings
                        } elseif ($null -ne $stream.stream.Settings.Framerate)
                        {
                            switch($FPS)
                            {
                                $null    {$settings = @{Resolution = $stream.Resolution}}
                                default  {$settings = @{Resolution = $stream.Resolution;Framerate = $newFPS}}
                            }
                            $stream.Stream | Set-VmsCameraStream -Settings $settings
                        } else
                        {
                            $settings = @{
                                Resolution = $stream.Resolution
                            }
                            $stream.Stream | Set-VmsCameraStream -Settings $settings
                        }
                    }

                    if (($cam | Get-VmsCameraStream -Enabled).Count -gt 1)
                    {
                        $lastStream = $cam | Get-VmsCameraStream -Enabled | Select-Object -Last 1
                        if ($ConfigureAdaptivePlayback)
                        {
                            $lastStream | Set-VmsCameraStream -LiveDefault -RecordingTrack Secondary -PlaybackDefault
                        } else {
                            $lastStream | Set-VmsCameraStream -LiveDefault
                        }
                    }
                    $camProcessed++
                }
            }
        }
    }
}