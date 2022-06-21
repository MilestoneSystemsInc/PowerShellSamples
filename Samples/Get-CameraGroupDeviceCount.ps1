function Get-CameraGroupDeviceCount
{
    <#
    .SYNOPSIS
        Calculates and displays the number of cameras in each camera group.

    .DESCRIPTION
        Will provide an output displaying the cumulative number of cameras in each group (including cameras in subgroups)
        as well as just cameras in that particular group (not including subgroups).  The -IncludeCameraNames switch can also
        be used to display the cameras that are in each group.

    .PARAMETER IncludeCameraNames
        Specifies the hostname of the Recording Server the script should be run against.  The hostname must
        exactly match the hostname shown in the Management Client.

    .EXAMPLE
        Get-CameraGroupDeviceCount

        Will create a tree report showing just the number of cameras in each camera group.

    .EXAMPLE
        Get-CameraGroupDeviceCount -IncludeCameraNames

        In addition to showing the number of cameras in each group, the report will also include the camera names.
    #>

    param(
        [Parameter(Mandatory = $false)]
        [switch] $IncludeCameraNames
    )

    Import-Module -Name MilestonePSTools

    # Get Camera groups
    $ms = Get-VmsManagementServer
    $cameraGroups = $ms.CameraGroupFolder.CameraGroups
    $cameraGroupInfo = New-Object System.Collections.Generic.List[PSCustomObject]

    # Call recursive function and only return the total camera count of the system.
    $totalCameraCount = Get-CameraGroupDeviceCountRecursive "" ([ref]$cameraGroupInfo) ([ref]$cameraGroups)

    $row = [PSCustomObject]@{
        'Group' = "!All Cameras"
        'CameraCount' = 0
        'CameraCountIncludingSublevels' = $totalCameraCount
        'CameraName' = $null
    }
    $cameraGroupInfo.Add($row)

    $cameraGroupInfo | Sort-Object Group, CameraCount, CameraName
}

function Get-CameraGroupDeviceCountRecursive ([string]$path,[ref]$cameraGroupInfo,[ref]$cameraGroups)
{
    <#
    .SYNOPSIS
        Don't run this script directly.  It gets run by Get-CameraGroupDeviceCount.
        Recursively goes through each camera group to get the camera counts and names.

    .DESCRIPTION
        Don't run this script directly.  It gets run by Get-CameraGroupDeviceCount.
        Recursively goes through each camera group to get the camera counts and names.
    #>

    $individualCameraCount = 0
    $combinedCameraCount = 0
    $totalCameraCount = 0

    if ($null -ne $cameraGroups.value.Name)
    {
        foreach ($cameraGroup in $cameraGroups.value)
        {
            $individualCameraCount = $cameraGroup.CameraFolder.Cameras.Count
            $combinedCameraCount = $individualCameraCount + (Get-CameraGroupDeviceCountRecursive "$($path)/$($cameraGroup.Name)" ([ref]$cameraGroupInfo.value) ([ref]$cameraGroup.CameraGroupFolder.CameraGroups))
            $row = [PSCustomObject]@{
                'Group' = "$($path)/$($cameraGroup.Name)"
                'CameraCount' = $individualCameraCount
                'CameraCountIncludingSublevels' = $combinedCameraCount
                'CameraName' = $null
            }
            $cameraGroupInfo.value.Add($row)
            $totalCameraCount += $combinedCameraCount

            if ($IncludeCameraNames)
            {
                $cameras = $cameraGroup.CameraFolder.Cameras

                foreach ($camera in $cameras)
                {
                    $row = [PSCustomObject]@{
                        'Group' = "$($path)/$($cameraGroup.Name)"
                        'CameraCount' = "xx"
                        'CameraCountIncludingSublevels' = $null
                        'CameraName' = $camera.Name
                    }
                $cameraGroupInfo.value.Add($row)
                }
            }
        }
    }
    return $totalCameraCount
}