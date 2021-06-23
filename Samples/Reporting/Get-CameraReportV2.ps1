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
        $initialSessionState = [initialsessionstate]::CreateDefault()
        foreach ($functionName in @('Get-StreamProperties', 'GetStreamNameFromStreamUsage', 'GetResolution', 'GetPropertyDisplayName')) {
            $definition = Get-Content Function:\$functionName -ErrorAction Stop
            $sessionStateFunction = [System.Management.Automation.Runspaces.SessionStateFunctionEntry]::new($functionName, $definition)
            $initialSessionState.Commands.Add($sessionStateFunction)
        }
        $runspacepool = [runspacefactory]::CreateRunspacePool(4, 16, $initialSessionState, $Host)
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

            $cameraEnabled = $Hardware.Enabled -and $Camera.Enabled

            function ConvertFrom-GisPoint {
                param ([string]$GisPoint)
            
                if ($GisPoint -eq 'POINT EMPTY') {
                    return [string]::Empty
                }
            
                $temp = $GisPoint.Substring(7, $GisPoint.Length - 8)
                $long, $lat, $null = $temp -split ' '
                return "$lat, $long"
            }
            
            $streamUsages = $Camera | Get-Stream -All
            $liveStreamSettings = $Camera | Get-StreamProperties -StreamName ($streamUsages | Where-Object LiveDefault | GetStreamNameFromStreamUsage)
            $recordedStreamSettings = $Camera | Get-StreamProperties -StreamName ($streamUsages | Where-Object Record | GetStreamNameFromStreamUsage)
            
            $motionDetection = $Camera.MotionDetectionFolder.MotionDetections[0]
            $hardwareSettings = $Hardware | Get-HardwareSetting
            $playbackInfo = @{ Begin = 'NotAvailable'; End = 'NotAvailable'}
            if ($cameraEnabled -and $camera.RecordingEnabled) {
                $playbackInfo = $Camera | Get-PlaybackInfo -ErrorAction Ignore -WarningAction Ignore
            }
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
                Enabled = $cameraEnabled
                State = $States | Where-Object { $_.FQID.ObjectId -eq $Camera.Id } | Select-Object -ExpandProperty State
                NetworkState = 'NotImplemented'
                Location = ConvertFrom-GisPoint -GisPoint $Camera.GisPoint
                LastModified = $Camera.LastModified
                Id = $Camera.Id
                HardwareName = $Hardware.Name
                Address = $Hardware.Address
                Username = $Hardware.UserName
                Password = $password
                HTTPSEnabled = if ($null -ne $hardwareSettings.HTTPSEnabled) { $hardwareSettings.HTTPSEnabled.ToUpper() } else { 'NO' }
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

                LiveResolution = GetPropertyDisplayName -PropertyList $liveStreamSettings -PropertyName 'Resolution', 'StreamProperty' #GetResolution -PropertyList $liveStreamSettings
                LiveCodec = GetPropertyDisplayName -PropertyList $liveStreamSettings -PropertyName 'Codec'
                LiveFPS = GetPropertyDisplayName -PropertyList $liveStreamSettings -PropertyName 'FPS', 'Framerate'
                LiveMode = $streamUsages | Where-Object LiveDefault | Select-Object -ExpandProperty LiveMode
                RecordResolution = GetPropertyDisplayName -PropertyList $recordedStreamSettings -PropertyName 'Resolution', 'StreamProperty' #GetResolution -PropertyList $recordedStreamSettings
                RecordCodec = GetPropertyDisplayName -PropertyList $recordedStreamSettings -PropertyName 'Codec'
                RecordFPS = GetPropertyDisplayName -PropertyList $recordedStreamSettings -PropertyName 'FPS', 'Framerate'

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
            Status = 'Preparing to run report'
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


function GetStreamNameFromStreamUsage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VideoOS.Platform.ConfigurationItems.StreamUsageChildItem]
        $StreamUsage
    )

    $streamName = $StreamUsage.StreamReferenceIdValues.Keys | Where-Object {
        $StreamUsage.StreamReferenceIdValues.$_ -eq $StreamUsage.StreamReferenceId
    }
    Write-Output $streamName
}

function GetResolution {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [VideoOS.ConfigurationApi.ClientService.Property[]]
        $PropertyList
    )
    
    process {
        $result = $null
        foreach ($propertyName in @('Resolution', 'StreamProperty')) {
            $result = GetPropertyDisplayName -PropertyList $PropertyList -PropertyName $propertyName
            if ($result -ne 'NotAvailable') {
                break
            }
        }
        Write-Output $result
    }
}

function GetPropertyDisplayName {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [VideoOS.ConfigurationApi.ClientService.Property[]]
        $PropertyList,

        [Parameter(Mandatory)]
        [string[]]
        $PropertyName,

        [Parameter()]
        [string]
        $DefaultValue = 'NotAvailable'
    )
    
    process {
        $value = $DefaultValue
        if ($null -eq $PropertyList -or $PropertyList.Count -eq 0) {
            return $value
        }

        $selectedProperty = $null
        foreach ($property in $PropertyList) {
            foreach ($name in $PropertyName) {
                if ($property.Key -like "*/$name/*") {
                    $selectedProperty = $property
                    break
                }
            }
            if ($null -ne $selectedProperty) { break }
        }
        if ($null -ne $selectedProperty) {
            $value = $selectedProperty.Value
            if ($selectedProperty.ValueType -eq 'Enum') {
                $displayName = ($selectedProperty.ValueTypeInfos | Where-Object Value -eq $selectedProperty.Value).Name
                if (![string]::IsNullOrWhiteSpace($displayName)) {
                    $value = $displayName
                }
            }
        }
        Write-Output $value
    }
}



function Get-StreamProperties {
    [CmdletBinding()]
    param (
        # Specifies the camera to retrieve stream properties for
        [Parameter(ValueFromPipeline, Mandatory, ParameterSetName = 'ByName')]
        [Parameter(ValueFromPipeline, Mandatory, ParameterSetName = 'ByNumber')]
        [VideoOS.Platform.ConfigurationItems.Camera]
        $Camera,
        
        # Specifies a StreamUsageChildItem from Get-Stream
        [Parameter(ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string]
        $StreamName,

        # Specifies the stream number starting from 0. For example, "Video stream 1" is usually in the 0'th position in the StreamChildItems collection.
        [Parameter(ParameterSetName = 'ByNumber')]
        [ValidateRange(0, [int]::MaxValue)]
        [int]
        $StreamNumber
    )
    
    process {
        switch ($PSCmdlet.ParameterSetName) {
            'ByName' {
                $stream = (Get-ConfigurationItem -Path "DeviceDriverSettings[$($Camera.Id)]").Children | Where-Object { $_.ItemType -eq 'Stream' -and $_.DisplayName -like $StreamName }
                if ($null -eq $stream -and ![system.management.automation.wildcardpattern]::ContainsWildcardCharacters($StreamName)) {
                    Write-Error "No streams found on $($Camera.Name) matching the name '$StreamName'"
                    return
                }
                foreach ($obj in $stream) {
                    Write-Output $obj.Properties
                }
            }
            'ByNumber' {
                $streams = (Get-ConfigurationItem -Path "DeviceDriverSettings[$($Camera.Id)]").Children | Where-Object { $_.ItemType -eq 'Stream' }
                if ($StreamNumber -lt $streams.Count) {
                    Write-Output ($streams[$StreamNumber].Properties)
                }
                else {
                    Write-Error "There are $($streams.Count) streams available on the camera and stream number $StreamNumber does not exist. Remember to index the streams from zero."
                }
            }
            Default {}
        }
        
    }
}