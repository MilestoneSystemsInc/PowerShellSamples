function Backup-MediaDb {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({Test-Path $_})]
        [string]
        $Destination,
        [Parameter()]
        [DateTime]
        $Start = [DateTime]::Now.AddYears(-100),
        [Parameter()]
        [DateTime]
        $End = [DateTime]::Now,
        [Parameter()]
        [string[]]
        $DeviceId
    )
    
    begin {
        $recorderConfig = Get-RecorderConfig
        if ($null -eq $recorderConfig) {
            throw "Get-RecorderConfig failed to return RecorderConfig information"
        }
    }
    
    process {
        $backupFolder = Join-Path $Destination $recorderConfig.RecorderId
        if (-not (Test-Path $backupFolder)) {
            $null = New-Item -Path $backupFolder -ItemType Directory -Force
        }
        
        $recorder = Get-RecordingServer -Id $recorderConfig.RecorderId
        foreach ($storage in $recorder.StorageFolder.Storages) {
            Backup-Storage -Storage $storage -Destination $backupFolder -Start $Start -End $End -DeviceId $DeviceId
        }
    }
    
    end {

    }
}