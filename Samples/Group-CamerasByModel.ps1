function Group-CamerasByModel {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $BaseGroupPath,
        [Parameter()]
        [int]
        [ValidateRange(1, 400)]
        $MaxGroupSize = 400
    )
    
    process {
        # We perform the grouping in two steps. Step 1 is collection of models
        # into $camsByModel where we collect all camera GUIDs and sort them by
        # model. Step 2 is to enumerate those models and create groups of size
        # $MaxGroupSize under a group named after each model.
        $camsByModel = New-Object 'System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[Guid]]'
        Write-Verbose "Gathering hardware information"
        Write-Progress -Activity "Collecting camera information"
        $totalCameras = 0
        foreach ($hw in Get-Hardware | Where-Object Enabled) {
            $model = $hw.Model.Replace('/', '`/')
            if (-not $camsByModel.ContainsKey($model)) {
                Write-Verbose "Discovered model '$model'"
                $list = New-Object System.Collections.Generic.List[Guid]
                $camsByModel.Add($model, $list)
            }
            
            $hw | Get-Camera | Where-Object Enabled | ForEach-Object {
                $camsByModel[$model].Add($_.Id)
                $totalCameras++
            }
            Write-Progress -Activity "Collecting camera information" -Status "Discovered $($camsByModel.Keys.Count) models and $totalCameras total cameras"
        }
        Write-Progress -Activity "Collecting camera information" -Completed

        try {
            # Remove the camera group at $BaseGroupPath if it exists
            # If we don't, then the groups will be a bit weird on subsequent
            # executions, and some stale groups could remain after device removals
            $group = Get-DeviceGroup -DeviceCategory camera -Path $BaseGroupPath
            $parentFolder = Get-ConfigurationItem -Path $group.ParentPath
            $taskInfo = $parentFolder | Invoke-Method -MethodId RemoveDeviceGroup
            ($taskInfo.Properties | Where-Object Key -eq "RemoveMembers").Value = "True"
            ($taskInfo.Properties | Where-Object Key -eq "ItemSelection").Value = $group.Path
            $task = $taskInfo | Invoke-Method -MethodId "RemoveDeviceGroup"
            if (($task.Properties | Where-Object Key -eq "State").Value -ne "Success") {
                throw "Error removing device group. Result:`r`n$($task | ConvertTo-Json)"
            }
        }
        catch [VideoOS.Platform.PathNotFoundMIPException] {
        }

        $camerasProcessed = 0
        foreach ($key in $camsByModel.Keys) {
            $groupNumber = 1
            $positionInGroup = 1
            $group = $null
            $totalForModel = $camsByModel[$key].Count
            for ($i = 0; $i -lt $camsByModel[$key].Count; $i++) {
                Write-Progress -Activity "Building camera groups" -Status $key -PercentComplete ($camerasProcessed / $totalCameras * 100)
                if ($null -eq $group) {
                    $first = $groupNumber * $MaxGroupSize - ($MaxGroupSize - 1)
                    $last = $groupNumber * $MaxGroupSize
                    if ($totalForModel - ($i + 1) -lt $MaxGroupSize) {
                        $last = $totalForModel
                    }
                    $groupName = "$first-$last"
                    Write-Verbose "Creating group $key/$groupName"
                    $group = Add-DeviceGroup -DeviceCategory Camera -Path "$BaseGroupPath/$key/$groupName"
                }

                try {
                    $null = $group.CameraFolder.AddDeviceGroupMember("Camera[$($camsByModel[$key][$i])]")
                }
                catch [VideoOS.Platform.ArgumentMIPException] {
                }
                
                $camerasProcessed++
                $positionInGroup++
                if ($positionInGroup -gt $MaxGroupSize) {
                    $group = $null
                    $positionInGroup = 1
                    $groupNumber++
                }
            } # for ($i = 0; $i -lt $camsByModel[$key].Count; $i++)
        } # foreach ($key in $camsByModel.Keys)
        Write-Progress -Activity "Building camera groups" -Status "Done" -PercentComplete 100 -Completed
    }
}