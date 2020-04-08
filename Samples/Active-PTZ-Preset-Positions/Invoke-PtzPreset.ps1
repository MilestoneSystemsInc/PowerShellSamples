function Invoke-PtzPreset {
    <#
    .SYNOPSIS
        Send a command to activate the specified PtzPreset resulting in the associated PTZ camera
        moving to the designated coordinates.

    .DESCRIPTION
        Send a command to activate the specified PtzPreset resulting in the associated PTZ camera
        moving to the designated coordinates.

        The PtzPreset parameter should reference an existing PTZ preset position configured in the
        VMS. This cmdlet cannot move a PTZ camera to an arbitratry user-defined coordinate.

    .PARAMETER PtzPreset
        The PtzPreset configuration item found under $camera.PtzPresetFolder.PtzPresets

    .PARAMETER VerifyCoordinates
        Wait for the camera to arrive at the designated PtzPreset coordinates. Only applies if the
        camera uses absolute PTZ positioning.

	.PARAMETER Tolerance
        Default: 0.001. Specifies the tolerance for PTZ coordinates as some cameras may not arrive
        at the exact coordinates.

    .PARAMETER Timeout
        Default: 5 seconds. Specifies the time in seconds to wait for the camera to arrive at the
        PtzPreset position. Only applies when the VerifyCoordinates switch is provided, and only
        for cameras using absolute PTZ positioning.

        Cameras with relative positioning, or calling this cmdlet without the VerifyCoordinates switch
        will result in an immediate return without waiting for the camera to complete it's movement.

    .EXAMPLE
        Invoke-PtzPreset -PtzPreset $ptzPreset -VerifyCoordinates

        Calls the $ptsPreset position and instructs the cmdlet to verify the camera has arrived at
        the designated position.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [VideoOS.Platform.ConfigurationItems.PtzPreset]
        $PtzPreset,

        [Parameter()]
        [switch]
        $VerifyCoordinates,
        
        [Parameter()]
        [double]
        $Tolerance = 0.001,
        
        [Parameter()]
        [int]
        $Timeout = 5
    )
    
    process {
        $cameraId = if ($PtzPreset.ParentItemPath -match 'Camera\[(.{36})\]') {
            $Matches[1]
        }
        else {
            Write-Error "Could not parse camera ID from ParentItemPath value '$($PtzPreset.ParentItemPath)'"
            return
        }

        $camera = Get-Camera -Id $cameraId
        $cameraItem = $camera | Get-PlatformItem
        $presetItem = [VideoOS.Platform.Configuration]::Instance.GetItem([guid]::new($PtzPreset.Id), [VideoOS.Platform.Kind]::Preset)
        
        $params = @{
            MessageId = 'Control.TriggerCommand'
            DestinationEndpoint = $presetItem.FQID
            UseEnvironmentManager = $true
        }
        Send-MipMessage @params

        if (-not $VerifyCoordinates) {
            return
        }

        if ($cameraItem.Properties['pan'] -ne 'Absolute' -or $cameraItem.Properties['pan'] -ne 'Absolute' -or $cameraItem.Properties['zoom'] -ne 'Absolute') {
            Write-Warning "VerifyCoordinates switch provided but camera does not use absolute PTZ positioning. Coordinates will not be verified."
            return
        }

        $positionReached = $false
        $stopwatch = [Diagnostics.StopWatch]::StartNew()
        while ($stopwatch.ElapsedMilliseconds -lt ($timeout * 1000)) {
            $position = Send-MipMessage -MessageId Control.PTZGetAbsoluteRequest -DestinationEndpoint $cameraItem.FQID -UseEnvironmentManager
            
            $xDifference = [Math]::Abs($position.Pan) - [Math]::Abs($ptzPreset.Pan)
            $yDifference = [Math]::Abs($position.Tilt) - [Math]::Abs($ptzPreset.Tilt)
            $zDifference = [Math]::Abs($position.Zoom) - [Math]::Abs($ptzPreset.Zoom)

            if ($xDifference -gt $Tolerance) {
                Write-Warning "Expected Pan = $($ptzPreset.Pan), Current Pan = $($position.Pan), Off by $xDifference"
            }
            elseif ($yDifference -gt $Tolerance) {
                Write-Warning "Desired Tilt = $($ptzPreset.Tilt), Current Pan = $($position.Tilt), Off by $yDifference"
            }
            elseif ($zDifference -gt $Tolerance) {
                Write-Warning "Desired Zoom = $($ptzPreset.Zoom), Current Pan = $($position.Zoom), Off by $zDifference"
            }
            else {
                $positionReached = $true
                break
            }
            Start-Sleep -Milliseconds 100
        }
        if (-not $positionReached) {
            Write-Error "Camera failed to reach preset position"
        }
    }
}