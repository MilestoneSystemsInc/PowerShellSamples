function Backup-Bank {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({Test-Path $_})]
        [string]
        $BankPath,
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
        $bankId = Split-Path -Path $BankPath -Leaf
        $backupFolder = Join-Path $Destination $bankId
        if (-not (Test-Path $backupFolder)) {
            $null = New-Item -Path $backupFolder -ItemType Directory -Force
        }

        Get-ChildItem -Path (Join-Path -Path $BankPath "*.xml") | Copy-Item -Destination $backupFolder

        foreach ($table in Get-BankTable -Path $BankPath -StartTime $Start -EndTime $End -DeviceId $DeviceId) {
            $source = $table.Path
            $dest = Join-Path $backupFolder (Split-Path $table.Path -Leaf)
            $log = Join-Path $backupFolder "robocopy.log"
            robocopy $source $dest /E /Z /NP /MT:8 /LOG+:$log
        }
    }
    
    end {

    }
}