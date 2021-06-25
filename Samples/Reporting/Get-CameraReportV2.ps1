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
        $IncludePlainTextPasswords,

        # Specifies that disabled cameras should be excluded from the results
        [Parameter()]
        [switch]
        $IncludeDisabled,

        # Specifies that a live JPEG snapshot should be requested for each camera
        [Parameter()]
        [switch]
        $IncludeSnapshots
    )

    begin {
        $initialSessionState = [initialsessionstate]::CreateDefault()
        foreach ($functionName in @('Get-StreamProperties', 'GetStreamNameFromStreamUsage', 'GetResolution', 'GetPropertyDisplayName', 'ConvertFrom-Snapshot', 'ConvertFrom-GisPoint')) {
            $definition = Get-Content Function:\$functionName -ErrorAction Stop
            $sessionStateFunction = [System.Management.Automation.Runspaces.SessionStateFunctionEntry]::new($functionName, $definition)
            $initialSessionState.Commands.Add($sessionStateFunction)
        }
        $runspacepool = [runspacefactory]::CreateRunspacePool(16, 16, $initialSessionState, $Host)
        $runspacepool.Open()
        $threads = New-Object System.Collections.Generic.List[pscustomobject]
        $processDevice = {
            param(
                [VideoOS.Platform.Messaging.ItemState[]]$States,
                [VideoOS.Platform.ConfigurationItems.RecordingServer]$RecordingServer,
                [hashtable]$VideoDeviceStatistics,
                [hashtable]$CurrentDeviceStatus,
                [hashtable]$StorageTable,
                [VideoOS.Platform.ConfigurationItems.Hardware]$Hardware,
                [VideoOS.Platform.ConfigurationItems.Camera]$Camera,
                [bool]$IncludePasswords,
                [bool]$IncludeSnapshots
            )
            
            $cameraEnabled = $Hardware.Enabled -and $Camera.Enabled
            $streamUsages = $Camera | Get-Stream -All
            $liveStreamSettings = $Camera | Get-StreamProperties -StreamName ($streamUsages | Where-Object LiveDefault | GetStreamNameFromStreamUsage)
            $recordedStreamSettings = $Camera | Get-StreamProperties -StreamName ($streamUsages | Where-Object Record | GetStreamNameFromStreamUsage)
            
            $motionDetection = $Camera.MotionDetectionFolder.MotionDetections[0]
            $hardwareSettings = $Hardware | Get-HardwareSetting
            $playbackInfo = @{ Begin = 'NotAvailable'; End = 'NotAvailable'}
            if ($cameraEnabled -and $camera.RecordingEnabled) {
                $tempPlaybackInfo = $Camera | Get-PlaybackInfo -ErrorAction Ignore -WarningAction Ignore
                if ($null -ne $tempPlaybackInfo) {
                    $playbackInfo = $tempPlaybackInfo
                }
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
            $cameraStatus = $CurrentDeviceStatus.$($RecordingServer.Id).CameraDeviceStatusArray | Where-Object DeviceId -eq $Camera.Id
            $statistics = $VideoDeviceStatistics.$($RecordingServer.Id) | Where-Object DeviceId -eq $Camera.Id
            $expectedRetention = New-Timespan -Minutes ($StorageTable.$($Camera.RecordingStorage) | ForEach-Object { $_; $_.ArchiveStorageFolder.ArchiveStorages } | Sort-Object RetainMinutes -Descending | Select-Object -First 1 -ExpandProperty RetainMinutes)
            $snapshot = $null
            if ($IncludeSnapshots -and $cameraEnabled -and $cameraStatus.Started) {
                $snapshot = $Camera | Get-Snapshot -Live -ErrorAction Ignore | ConvertFrom-Snapshot
            }
            elseif (!$IncludeSnapshots) {
                $snapshot = 'NotRequested'
            }
            [pscustomobject]@{
                Name = $Camera.Name
                Channel = $Camera.Channel
                Enabled = $cameraEnabled
                State = if ($cameraEnabled) { $States | Where-Object { $_.FQID.ObjectId -eq $Camera.Id } | Select-Object -ExpandProperty State } else { 'NotAvailable' }
                MediaOverflow = if ($cameraEnabled)  { $cameraStatus.ErrorOverflow } else { 'NotAvailable' }
                DbRepairInProgress = if ($cameraEnabled)  { $cameraStatus.DbRepairInProgress } else { 'NotAvailable' }
                DbWriteError = if ($cameraEnabled)  { $cameraStatus.ErrorWritingGop } else { 'NotAvailable' }
                GpsCoordinates = if ($Camera.GisPoint -eq 'POINT EMPTY') { 'NotSet' } else { ConvertFrom-GisPoint -GisPoint $Camera.GisPoint }
                MediaDatabaseBeginning = $playbackInfo.Begin
                MediaDatabaseEnd = $playbackInfo.End                
                UsedSpaceInBytes = if ($cameraEnabled) { $statistics | Select-Object -ExpandProperty UsedSpaceInBytes } else { 'NotAvailable' }

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

                ConfiguredLiveResolution = GetPropertyDisplayName -PropertyList $liveStreamSettings -PropertyName 'Resolution', 'StreamProperty' #GetResolution -PropertyList $liveStreamSettings
                ConfiguredLiveCodec = GetPropertyDisplayName -PropertyList $liveStreamSettings -PropertyName 'Codec'
                ConfiguredLiveFPS = GetPropertyDisplayName -PropertyList $liveStreamSettings -PropertyName 'FPS', 'Framerate'
                LiveMode = $streamUsages | Where-Object LiveDefault | Select-Object -ExpandProperty LiveMode
                ConfiguredRecordResolution = GetPropertyDisplayName -PropertyList $recordedStreamSettings -PropertyName 'Resolution', 'StreamProperty' #GetResolution -PropertyList $recordedStreamSettings
                ConfiguredRecordCodec = GetPropertyDisplayName -PropertyList $recordedStreamSettings -PropertyName 'Codec'
                ConfiguredRecordFPS = GetPropertyDisplayName -PropertyList $recordedStreamSettings -PropertyName 'FPS', 'Framerate'

                CurrentLiveResolution = if ($cameraEnabled) { $statistics | Select-Object -ExpandProperty VideoStreamStatisticsArray | Where-Object LiveStreamDefault | Select-Object -ExpandProperty ImageResolution -First 1 | Foreach-Object { "$($_.Width)x$($_.Height)" } } else { 'NotAvailable' }
                CurrentLiveFPS = if ($cameraEnabled) { $statistics | Select-Object -ExpandProperty VideoStreamStatisticsArray | Where-Object LiveStreamDefault | Select-Object -ExpandProperty FPS -First 1 } else { 'NotAvailable' }
                CurrentLiveBPS = if ($cameraEnabled) { $statistics | Select-Object -ExpandProperty VideoStreamStatisticsArray | Where-Object LiveStreamDefault | Select-Object -ExpandProperty BPS -First 1 } else { 'NotAvailable' }
                CurrentRecordedResolution = if ($cameraEnabled) { $statistics | Select-Object -ExpandProperty VideoStreamStatisticsArray | Where-Object RecordingStream | Select-Object -ExpandProperty ImageResolution -First 1 | Foreach-Object { "$($_.Width)x$($_.Height)" } } else { 'NotAvailable' }
                CurrentRecordedFPS = if ($cameraEnabled) { $statistics | Select-Object -ExpandProperty VideoStreamStatisticsArray | Where-Object RecordingStream | Select-Object -ExpandProperty FPS -First 1 } else { 'NotAvailable' }
                CurrentRecordedBPS = if ($cameraEnabled) { $statistics | Select-Object -ExpandProperty VideoStreamStatisticsArray | Where-Object RecordingStream | Select-Object -ExpandProperty BPS -First 1 } else { 'NotAvailable' }

                RecordingEnabled = $Camera.RecordingEnabled
                RecordKeyframesOnly = $Camera.RecordKeyframesOnly
                RecordOnRelatedDevices = $Camera.RecordOnRelatedDevices
                PrebufferEnabled = $Camera.PrebufferEnabled
                PrebufferSeconds = $Camera.PrebufferSeconds
                PrebufferInMemory = $Camera.PrebufferInMemory

                RecordingStorageName = $StorageTable.$($Camera.RecordingStorage).Name
                RecordingPath = [io.path]::Combine($StorageTable.$($Camera.RecordingStorage).DiskPath, $StorageTable.$($Camera.RecordingStorage).Id)
                ExpectedRetention = $expectedRetention
                ActualRetention = if ($playbackInfo.Begin -is [string]) { 'NotAvailable' } else { [datetime]::UtcNow - $playbackInfo.Begin }
                MeetsRetentionPolicy = if ($playbackInfo.Begin -is [string]) { 'NotAvailable' } else { ([datetime]::UtcNow - $playbackInfo.Begin) -ge $expectedRetention }

                MotionEnabled = $motionDetection.Enabled
                MotionKeyframesOnly = $motionDetection.KeyframesOnly
                MotionProcessTime = $motionDetection.ProcessTime
                MotionSensitivityMode = if ($motionDetection.ManualSensitivityEnabled) { 'Manual' } else { 'Automatic' }
                MotionManualSensitivity = $motionDetection.ManualSensitivity
                MotionMetadataEnabled = $motionDetection.GenerateMotionMetadata
                MotionExcludeRegions = if ($motionDetection.UseExcludeRegions) { 'Yes' } else { 'No' }
                MotionHardwareAccelerationMode = $motionDetection.HardwareAccelerationMode

                Snapshot = $snapshot
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
        $progressParams.CurrentOperation = 'Calling Get-ItemState'
        Write-Progress @progressParams
        $itemState = Get-ItemState -ErrorAction Stop

        Write-Verbose 'Discovering all cameras and retrieving status and statistics'
        $progressParams.CurrentOperation = 'Discovering all cameras and retrieving status and statistics'
        Write-Progress @progressParams

        try {
            $respondingRecordingServers = $RecordingServer.Id | Where-Object { $id = $_; $id -in $itemState.FQID.ObjectId -and ($itemState | Where-Object { $id -eq $_.FQID.ObjectId }).State -eq 'Server Responding' }
            Write-Debug -Message 'Retrieving status and statistics from the Recording Server'
            $videoDeviceStatistics = Get-VideoDeviceStatistics -AsHashtable -RecordingServerId $respondingRecordingServers
            $currentDeviceStatus = Get-CurrentDeviceStatus -AsHashtable -RecordingServerId $respondingRecordingServers
            $storageTable = @{}
            foreach ($rs in $RecordingServer) {
                $rs.StorageFolder.Storages | Foreach-Object {
                    $_.FillChildren('StorageArchive')
                    $storageTable.$($_.Path) = $_
                }
                foreach ($hw in $rs | Get-Hardware) {
                    foreach ($cam in $hw | Get-Camera) {
                        if (!$IncludeDisabled -and -not ($cam.Enabled -and $hw.Enabled)) {
                            continue
                        }
                        $ps = [powershell]::Create()
                        $ps.RunspacePool = $runspacepool
                        $asyncResult = $ps.AddScript($processDevice).AddParameters(@{
                            State = $itemState
                            RecordingServer = $rs
                            VideoDeviceStatistics = $videoDeviceStatistics
                            CurrentDeviceStatus = $currentDeviceStatus
                            StorageTable = $storageTable
                            Hardware = $hw
                            Camera = $cam
                            IncludePasswords = $IncludePlainTextPasswords
                            IncludeSnapshots = $IncludeSnapshots
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
                $progressParams.Status = "Processed $($totalDevices - $threads.Count) out of $totalDevices cameras"
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



function Get-CurrentDeviceStatus {
    <#
    .SYNOPSIS
        Gets the current device status of all devices of the desired type from one or more recording servers
    .DESCRIPTION
        Uses the RecorderStatusService2 client to call GetCurrentDeviceStatus and receive the current status
        of all devices of the desired type(s). Specify one or more types in the DeviceType parameter to receive
        status of more device types than cameras.
    .EXAMPLE
        PS C:\> Get-RecordingServer -Name 'My Recording Server' | Get-CurrentDeviceStatus -DeviceType All
        Gets the status of all devices of all device types from the Recording Server named 'My Recording Server'.
    .EXAMPLE
        PS C:\> Get-CurrentDeviceStatus -DeviceType Camera, Microphone
        Gets the status of all cameras and microphones from all recording servers.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        # Specifies one or more Recording Server ID's to which the results will be limited. Omit this parameter if you want device status from all Recording Servers
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [guid[]]
        $RecordingServerId,

        # Specifies the type of devices to include in the results. By default only cameras will be included and you can expand this to include all device types
        [Parameter()]
        [ValidateSet('Camera', 'Microphone', 'Speaker', 'Metadata', 'Input event', 'Output', 'Event', 'Hardware', 'All')]
        [string[]]
        $DeviceType = 'Camera',

        # Specifies that the output should be provided in a complete hashtable instead of one pscustomobject value at a time
        [Parameter()]
        [switch]
        $AsHashTable
    )

    process {
        if ($DeviceType -contains 'All') {
            $DeviceType = @('Camera', 'Microphone', 'Speaker', 'Metadata', 'Input event', 'Output', 'Event', 'Hardware')
        }
        $includedDeviceTypes = $DeviceType | Foreach-Object { [videoos.platform.kind]::$_ }
        
        Write-Verbose "Creating a runspace pool"
        $pool = [runspacefactory]::CreateRunspacePool(4, 8)
        $pool.Open()

        $scriptBlock = {
            param(
                [uri]$Uri,
                [guid[]]$DeviceIds
            )
            try {
                $client = [VideoOS.Platform.SDK.Proxy.Status2.RecorderStatusService2]::new($Uri)
                $client.GetCurrentDeviceStatus((Get-Token), $deviceIds)
            }
            catch {
                throw "Unable to get current device status from $Uri"
            }
            
        }

        Write-Verbose 'Retrieving recording server information'
        $managementServer = [videoos.platform.configuration]::Instance.GetItems([videoos.platform.itemhierarchy]::SystemDefined) | Where-Object { $_.FQID.Kind -eq [videoos.platform.kind]::Server -and $_.FQID.ObjectId -eq (Get-ManagementServer).Id }
        $recorders = $managementServer.GetChildren() | Where-Object { $_.FQID.ServerId.ServerType -eq 'XPCORS' -and ($null -eq $RecordingServerId -or $_.FQID.ObjectId -in $RecordingServerId) }
        Write-Verbose "Retrieving video device statistics from $($recorders.Count) recording servers"
        try {
            $threads = New-Object System.Collections.Generic.List[pscustomobject]
            foreach ($recorder in $recorders) {
                Write-Verbose "Requesting device status from $($recorder.Name) at $($recorder.FQID.ServerId.Uri)"
                $folders = $recorder.GetChildren() | Where-Object { $_.FQID.Kind -in $includedDeviceTypes -and $_.FQID.FolderType -eq [videoos.platform.foldertype]::SystemDefined}
                $deviceIds = [guid[]]($folders | Foreach-Object {
                    $children = $_.GetChildren()
                    if ($null -ne $children -and $children.Count -gt 0) {
                        $children.FQID.ObjectId
                    }
                })
    
                $ps = [powershell]::Create()
                $ps.RunspacePool = $pool
                $asyncResult = $ps.AddScript($scriptBlock).AddParameters(@{
                    Uri = $recorder.FQID.ServerId.Uri
                    DeviceIds = $deviceIds
                }).BeginInvoke()
                $threads.Add([pscustomobject]@{
                    RecordingServerId = $recorder.FQID.ObjectId
                    PowerShell = $ps
                    Result = $asyncResult
                })
            }
    
            if ($threads.Count -eq 0) {
                return
            }
    
            $hashTable = @{}
            $completedThreads = New-Object System.Collections.Generic.List[pscustomobject]
            while ($threads.Count -gt 0) {
                foreach ($thread in $threads) {
                    if ($thread.Result.IsCompleted) {
                        Write-Verbose "Receiving results from recording server with ID $($thread.RecordingServerId)"
                        if ($AsHashTable) {
                            $hashTable.$($thread.RecordingServerId.ToString()) = $null
                        }
                        else {
                            $obj = @{
                                RecordingServerId = $thread.RecordingServerId.ToString()
                                CurrentDeviceStatus = $null
                            }
                        }
                        try {
                            $result = $thread.PowerShell.EndInvoke($thread.Result) | ForEach-Object { Write-Output $_ }
                            if ($AsHashTable) {
                                $hashTable.$($thread.RecordingServerId.ToString()) = $result
                            }
                            else {                                    
                                $obj.CurrentDeviceStatus = $result
                            }
                        }
                        catch {
                            Write-Error $_
                        }
                        finally {
                            $thread.PowerShell.Dispose()
                            $completedThreads.Add($thread)
                            if (!$AsHashTable) {
                                Write-Output ([pscustomobject]$obj)
                            }
                        }
                    }
                }
                $completedThreads | Foreach-Object { [void]$threads.Remove($_)}
                $completedThreads.Clear()
                if ($threads.Count -eq 0) {
                    break;
                }
                Start-Sleep -Milliseconds 250
            }
            if ($AsHashTable) {
                Write-Output $hashTable
            }
        }
        finally {
            if ($threads.Count -gt 0) {
                Write-Warning "Stopping $($threads.Count) running PowerShell instances. This may take a minute. . ."
                foreach ($thread in $threads) {
                    $thread.PowerShell.Dispose()
                }
            }
            $pool.Close()
            $pool.Dispose()
        }
    }
}



function Get-VideoDeviceStatistics {
    <#
    .SYNOPSIS
        Gets the current device status of all devices of the desired type from one or more recording servers
    .DESCRIPTION
        Uses the RecorderStatusService2 client to call GetCurrentDeviceStatus and receive the current status
        of all devices of the desired type(s). Specify one or more types in the DeviceType parameter to receive
        status of more device types than cameras.
    .EXAMPLE
        PS C:\> Get-RecordingServer -Name 'My Recording Server' | Get-CurrentDeviceStatus -DeviceType All
        Gets the status of all devices of all device types from the Recording Server named 'My Recording Server'.
    .EXAMPLE
        PS C:\> Get-CurrentDeviceStatus -DeviceType Camera, Microphone
        Gets the status of all cameras and microphones from all recording servers.
    #>
    [CmdletBinding()]
    param (
        # Specifies one or more Recording Server ID's to which the results will be limited. Omit this parameter if you want device status from all Recording Servers
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [guid[]]
        $RecordingServerId,

        # Specifies that the output should be provided in a complete hashtable instead of one pscustomobject value at a time
        [Parameter()]
        [switch]
        $AsHashTable
    )

    process {        
        Write-Verbose "Creating a runspace pool"
        $pool = [runspacefactory]::CreateRunspacePool(4, 8)
        $pool.Open()

        $scriptBlock = {
            param(
                [uri]$Uri,
                [guid[]]$DeviceIds
            )
            try {
                $client = [VideoOS.Platform.SDK.Proxy.Status2.RecorderStatusService2]::new($Uri)
                $client.GetVideoDeviceStatistics((Get-Token), $deviceIds)
            }
            catch {
                throw "Unable to get video device statistics from $Uri"
            }
            
        }

        Write-Verbose 'Retrieving recording server information'
        $managementServer = [videoos.platform.configuration]::Instance.GetItems([videoos.platform.itemhierarchy]::SystemDefined) | Where-Object { $_.FQID.Kind -eq [videoos.platform.kind]::Server -and $_.FQID.ObjectId -eq (Get-ManagementServer).Id }
        $recorders = $managementServer.GetChildren() | Where-Object { $_.FQID.ServerId.ServerType -eq 'XPCORS' -and ($null -eq $RecordingServerId -or $_.FQID.ObjectId -in $RecordingServerId) }
        Write-Verbose "Retrieving video device statistics from $($recorders.Count) recording servers"
        try {
            $threads = New-Object System.Collections.Generic.List[pscustomobject]
            foreach ($recorder in $recorders) {
                Write-Verbose "Requesting video device statistics from $($recorder.Name) at $($recorder.FQID.ServerId.Uri)"
                $folders = $recorder.GetChildren() | Where-Object { $_.FQID.Kind -eq [videoos.platform.kind]::Camera -and $_.FQID.FolderType -eq [videoos.platform.foldertype]::SystemDefined}
                $deviceIds = [guid[]]($folders | Foreach-Object {
                    $children = $_.GetChildren()
                    if ($null -ne $children -and $children.Count -gt 0) {
                        $children.FQID.ObjectId
                    }
                })
    
                $ps = [powershell]::Create()
                $ps.RunspacePool = $pool
                $asyncResult = $ps.AddScript($scriptBlock).AddParameters(@{
                    Uri = $recorder.FQID.ServerId.Uri
                    DeviceIds = $deviceIds
                }).BeginInvoke()
                $threads.Add([pscustomobject]@{
                    RecordingServerId = $recorder.FQID.ObjectId
                    PowerShell = $ps
                    Result = $asyncResult
                })
            }
    
            if ($threads.Count -eq 0) {
                return
            }
    
            $hashTable = @{}
            $completedThreads = New-Object System.Collections.Generic.List[pscustomobject]
            while ($threads.Count -gt 0) {
                foreach ($thread in $threads) {
                    if ($thread.Result.IsCompleted) {
                        Write-Verbose "Receiving results from recording server with ID $($thread.RecordingServerId)"
                        if ($AsHashTable) {
                            $hashTable.$($thread.RecordingServerId.ToString()) = $null
                        }
                        else {
                            $obj = @{
                                RecordingServerId = $thread.RecordingServerId.ToString()
                                VideoDeviceStatistics = $null
                            }
                        }
                        try {
                            $result = $thread.PowerShell.EndInvoke($thread.Result) | ForEach-Object { Write-Output $_ }
                            if ($AsHashTable) {
                                $hashTable.$($thread.RecordingServerId.ToString()) = $result
                            }
                            else {                                    
                                $obj.VideoDeviceStatistics = $result
                            }
                        }
                        catch {
                            Write-Error $_
                        }
                        finally {
                            $thread.PowerShell.Dispose()
                            $completedThreads.Add($thread)
                            if (!$AsHashTable) {
                                Write-Output ([pscustomobject]$obj)
                            }
                        }
                    }
                }
                $completedThreads | Foreach-Object { [void]$threads.Remove($_)}
                $completedThreads.Clear()
                if ($threads.Count -eq 0) {
                    break;
                }
                Start-Sleep -Milliseconds 250
            }
            if ($AsHashTable) {
                Write-Output $hashTable
            }
        }
        finally {
            if ($threads.Count -gt 0) {
                Write-Warning "Stopping $($threads.Count) running PowerShell instances. This may take a minute. . ."
                foreach ($thread in $threads) {
                    $thread.PowerShell.Dispose()
                }
            }
            $pool.Close()
            $pool.Dispose()            
        }
    }
}



function ConvertFrom-Snapshot {
    <#
    .SYNOPSIS
        Converts from the output provided by Get-Snapshot to a [System.Drawing.Image] object.
    .DESCRIPTION
        Converts from the output provided by Get-Snapshot to a [System.Drawing.Image] object. Don't
        forget to call Dispose() on Image when you're done with it!
    .EXAMPLE
        PS C:\> $image = $camera | Get-Snapshot -Live | ConvertFrom-Snapshot
        Get's a live snapshot from $camera and converts it to a System.Drawing.Image object and saves it to $image
    .INPUTS
        Accepts a byte array, and will accept the byte array from Get-Snapshot by property name. The property name for
        a live image is 'Content' while the property name for the JPEG byte array on a snapshot from recorded video is
        'Bytes'.
    .OUTPUTS
        [System.Drawing.Image]
    .NOTES
        Don't forget to call Dispose() when you're done with the image!
    #>
    [CmdletBinding()]
    [OutputType([system.drawing.image])]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('Bytes')]
        [byte[]]
        $Content
    )

    process {
        if ($null -eq $Content -or $Content.Length -eq 0) {
            return $null
        }
        $ms = [io.memorystream]::new($Content)
        Write-Output ([system.drawing.image]::FromStream($ms))
    }
}

function ConvertFrom-GisPoint {
    param ([string]$GisPoint)

    if ($GisPoint -eq 'POINT EMPTY') {
        return [string]::Empty
    }

    $temp = $GisPoint.Substring(7, $GisPoint.Length - 8)
    $long, $lat, $null = $temp -split ' '
    return "$lat, $long"
}