#Requires -Modules MilestonePSTools
function Get-VmsCameraDiskUsage {
    <#
    .SYNOPSIS
        Gets the amount of space used and space available per live and archive storage area associated with a given camera
    .DESCRIPTION
        Uses an UNSUPPORTED API to access storage information per camera that is not available yet via the supported MIP SDK libraries.
        Requires the Milestone XProtect Management Client to be installed on the machine on which the function is executed as it relies
        on a DLL for serialization and deserialization of command requests/results issued through an IServerProxyService client
        which is also NOT a Milestone-supported API.

        These API's are subject to change at any time and it should not be a surprise if these interfaces change or break between versions.
        This function is purely experimental and does not represent recommended practice for Milestone solution partners.
    .EXAMPLE
        PS C:\> Get-Hardware | Get-Camera | Get-VmsCameraDiskUsage | Out-GridView
        Gets the disk usage information for all cameras and all storages used by those cameras and displays them in a grid view
    .PARAMETER Camera
        Specifies the Camera object for which to retrieve disk usage information
    .NOTES
        Here be dragons! This function uses unsupported Milestone API's which are used internally and subject to change between versions. The stability
        developers have come to appreciate from the MIP SDK and supported API's is not present here. Use at your own risk, and if it breaks, we cannot promise to fix it.
        We do hope to get this capability natively in the MIP SDK in the near future obsolete this code :)

        Known Issue: AvailableSpace values may not make sense. This is probably an unused field and may never have returned accurate values.
        Known Issue: If you use edge storage, this function does not yet take into consideration the edge recording track associated with the main camera recording track.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [VideoOS.Platform.ConfigurationItems.Camera]
        $Camera
    )

    begin {
        $dllPath = 'C:\Program Files\Milestone\XProtect Management Client\VideoOS.Common.Integration.dll'
        if (-not (Test-Path -Path $dllPath)) {
            Write-Warning "Milestone XProtect Management Client must be installed. The file VideoOS.Common.Integration.dll could not be found."
            throw "File not found: $dllPath"
        }
        [void][System.Reflection.Assembly]::LoadFrom($dllPath)
    }

    process {
        $item = Get-PlatformItem -Id $Camera.Id
        if ($null -eq $item) {
            $recorderId = Get-ConfigurationItem -Path $Camera.ParentItemPath -ParentItem | Get-ConfigurationItemProperty -Key Id
        }
        else {
            $recorderId = $item.FQID.ServerId.Id
        }
        
        # Would like to figure out how to find the edge storage track for a given camera and add that too
        $deviceIds = [array]@($Camera.Id)

        $cmd = [VideoOS.Common.Integration.Command.DatabaseOperationCommand]::new()
        $cmd.DatabaseOperationType = [VideoOS.Common.Integration.Command.DatabaseOperation]::DiskUsageInformationTablesPerStorage
        $cmd.RecorderId = $recorderId
        $cmd._deviceIds = $deviceIds
        $cmd.Token = New-Guid

        $svc = Get-IServerProxyService
        $proxyId = New-Guid
        $svc.SendCommand($proxyId, $cmd)

        $response = $svc.GetResponses($proxyId, (New-TimeSpan -Seconds 10))
        if ($response.Status -ne [VideoOS.Common.Integration.Command.DatabaseResponseStatus]::Error) {
            foreach ($diskUsage in $response.DatabaseResponseDiskUsageList) {
                if ($diskUsage.Status -eq [VideoOS.Common.Integration.Command.DatabaseResponseStatus]::Error) {
                    Write-Error $diskUsage.Message
                }
                if ($diskUsage.Status -eq [VideoOS.Common.Integration.Command.DatabaseResponseStatus]::Warning) {
                    Write-Warning $diskUsage.Message
                }
                [pscustomobject]@{
                    PSTypeName = 'DiskUsageInformationResponse'
                    CameraId = $diskUsage.Id
                    StorageId = $diskUsage.StorageId
                    RecorderId = $diskUsage.RecorderId
                    UsedSpace = $diskUsage.UsedSpace
                    AvailableSpace = $diskUsage.AvailableSpace
                    IsOnline = $diskUsage.IsOnline
                }
            }
        }
    }
}