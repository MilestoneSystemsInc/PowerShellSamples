function Backup-Storage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [VideoOS.Platform.ConfigurationItems.Storage]
        $Storage,
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
    }
    
    process {
        $Storage | ConvertTo-Json | Out-File -FilePath (Join-Path $Destination "$($Storage.Id).json")
        $backupFolder = Join-Path $Destination $Storage.Id
        if (-not (Test-Path $backupFolder)) {
            $null = New-Item -Path $backupFolder -ItemType Directory -Force
        }

        Backup-Bank -BankPath (Join-Path $Storage.DiskPath $Storage.Id) -Destination $backupFolder -Start $Start -End $End -DeviceId $DeviceId
        foreach ($archive in $Storage.ArchiveStorageFolder.ArchiveStorages | Sort-Object RetainMinutes) {
            Backup-Bank -BankPath (Join-Path $archive.DiskPath $archive.Id) -Destination $backupFolder -Start $Start -End $End -DeviceId $DeviceId
        }
    }
    
    end {

    }
}