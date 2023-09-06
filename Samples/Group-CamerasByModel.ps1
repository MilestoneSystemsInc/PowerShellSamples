function Group-CamerasByModel {
    <#
    .SYNOPSIS
    Creates a camera group for each camera make and model.
    
    .DESCRIPTION
    Creates a specified base camera group, and within that base group, it creates a group for every enabled camera
    make/model. For each camera model, a group is created with a name like 1-X where X is the number of cameras in that
    group. If the number exceeds 400, it will create another group called 401-X, until all enabled cameras of that model
    have been added to a group.
    
    Groups larger than 400 should not be created as the Management Client will not be able to do bulk configurations on them.

    Having groups of camera models is very useful for doing bulk configurations. Note that in some instances, cameras
    report their models as a series of cameras and not a specific model. In cases like this, bulk configuration will
    likely not work as the cameras in the series might support different resolutions and/or frame rates.
    
    .PARAMETER BaseGroupPath
    Specifies the camera group under which cameras should be grouped by model. For example, "/__ADMIN__/Models".
    
    .PARAMETER MaxGroupSize
    Specifies the maximum number of cameras to add to a single camera group. The default value is 400 which is also the maximum
    number of cameras the Management Client will allow bulk configuration operations on.
    
    .EXAMPLE
    Group-CamerasByModel -BaseGroupPath /__ADMIN__/Models

    Creates a top-level group called "__ADMIN__" which will typically be listed at the top of the device group list, and
    a "Models" subgroup. Cameras are then grouped by model under the Models camera subgroup.

    .EXAMPLE
    Group-CamerasByModel -BaseGroupPath /zzADMIN/Models -MaxGroupSize 200

    Creates a top-level group called "zzADMIN__" which will typically be listed at the bottom of the device group list, and
    a "Models" subgroup. Cameras are then grouped by model under the Models camera subgroup with a maximum group size of
    200 cameras.

    .NOTES
    For reference, on a 5217 camera test system with 148 unique models, this function completes in 6 minutes 13 seconds.
    The time required to run in your environment may vary based on many factors including total number of cameras and
    models, management server and/or sql server load, and latency between the PowerShell session and the management server.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ValueFromPipelineByPropertyName, Mandatory)]
        [string]
        $BaseGroupPath,

        [Parameter(Position = 1, ValueFromPipelineByPropertyName)]
        [ValidateRange(1, 400)]
        [int]
        $MaxGroupSize = 400
    )

    process {
        $parentProgress = @{
            Activity        = 'Creating camera groups by model'
            Status          = 'Discovering camera models'
            Id              = Get-Random
            PercentComplete = 0
        }
        $childProgress = @{
            Activity        = 'Populating camera groups'
            Id              = Get-Random
            ParentId        = $parentProgress.Id
            PercentComplete = 0
        }
        try {
            Write-Progress @parentProgress
            
            Write-Verbose "Removing camera group '$BaseGroupPath' if present"
            Clear-VmsCache
            Get-VmsDeviceGroup -Path $BaseGroupPath -ErrorAction SilentlyContinue | Remove-VmsDeviceGroup -Recurse -Confirm:$false -ErrorAction Stop
            
            Write-Verbose 'Discovering all enabled cameras'
            $ms = [VideoOS.Platform.ConfigurationItems.ManagementServer]::new((Get-VmsSite).FQID.ServerId)
            $filters = 'RecordingServer', 'Hardware', 'Camera' | ForEach-Object {
                [VideoOS.ConfigurationApi.ClientService.ItemFilter]::new($_, $null, 'Enabled')
            }
            $ms.FillChildren($filters.ItemType, $filters)

            $parentProgress.Status = 'Grouping and sorting cameras'
            Write-Progress @parentProgress

            Write-Verbose 'Sorting cameras by model'
            $modelGroups = $ms.RecordingServerFolder.RecordingServers.HardwareFolder.Hardwares | Group-Object Model | Sort-Object Name
            $totalCameras = ($modelGroups.Group.CameraFolder.Cameras).Count
            $camerasProcessed = 0

            $parentProgress.Status = 'Processing'
            Write-Progress @parentProgress

            foreach ($group in $modelGroups) {
                $modelName = $group.Name
                $safeModelName = $modelName.Replace('/', '`/')

                $cameras = $group.Group.CameraFolder.Cameras | Sort-Object Name
                $totalForModel = $cameras.Count
                
                $groupNumber = $positionInGroup = 1
                $group = $null
                
                $childProgress.Status = "Current: $BaseGroupPath/$modelName"                
                $parentProgress.PercentComplete = $camerasProcessed / $totalCameras * 100
                Write-Progress @parentProgress

                Write-Verbose "Creating groups for $totalForModel cameras of model '$modelName'"
                for ($i = 0; $i -lt $totalForModel; $i++) {
                    $childProgress.PercentComplete = $i / $totalForModel * 100
                    Write-Progress @childProgress
                    if ($null -eq $group) {
                        $first = $groupNumber * $MaxGroupSize - ($MaxGroupSize - 1)
                        $last = $groupNumber * $MaxGroupSize
                        if ($totalForModel - ($i + 1) -lt $MaxGroupSize) {
                            $last = $totalForModel
                        }
                        $groupName = '{0}-{1}' -f $first, $last
                        Write-Verbose "Creating group $BaseGroupPath/$modelName/$groupName"
                        $group = New-VmsDeviceGroup -Type Camera -Path "$BaseGroupPath/$safeModelName/$groupName"
                    }

                    Add-VmsDeviceGroupMember -Group $group -Device $cameras[$i]

                    $camerasProcessed++
                    $positionInGroup++
                    if ($positionInGroup -gt $MaxGroupSize) {
                        $group = $null
                        $positionInGroup = 1
                        $groupNumber++
                    }
                }
            }
        } finally {
            $childProgress.Completed = $true
            Write-Progress @childProgress
            
            $parentProgress.Completed = $true
            Write-Progress @parentProgress
        }
    }
}
