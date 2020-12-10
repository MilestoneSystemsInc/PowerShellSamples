<#
.SYNOPSIS

Creates a scheduled task in Windows to export all LPR events from the past 7 days to a CSV file.

.DESCRIPTION

This script will prompt the user for a path to store the server address and credentials in a
configuration file, followed by the VMS server address, credentials, and whether the credential is
for a basic user. These settings will be stored in the given file path as configuration.xml after
we have verified we can login to the VMS using the given credentials.

A scheduled task will then be created to run once every day at 7am. That task will login to the
VMS, retrieve all 'LPR Event' events for the last 7 days, and export them to a csv file in the
provided path. A log file will also be created which is useful for troubleshooting.

This script is designed to be run again if you want to change something. If the scheduled task
already exists, it will be removed before creating a new one.

#>

#Requires -RunAsAdministrator
#Requires -Modules MilestonePSTools
$InformationPreference = "Continue"
$ErrorActionPreference = "Stop"

$path = Read-Host -Prompt "Path to store configuration and reports"
if (-not (Test-Path $path)) {
    $null = mkdir $path
}

do {
    try {
        $serverAddress = Read-Host -Prompt "Milestone VMS Server Address"
        $credential = Get-Credential -Message "Milestone VMS Credentials"
        $basicUser = (Read-Host -Prompt "Basic User? (y/n)") -eq 'y'
        Write-Information "Testing VMS server connection. . ."
        Connect-ManagementServer -Server $serverAddress -Credential $credential -BasicUser:$basicUser
        Write-Information "VMS connection successful. Disconnecting. . ."
        Disconnect-ManagementServer
        Write-Information "Disconnected"
        break
    }
    catch {
        Write-Warning "Connection to the VMS failed. Please re-enter the information."
    }
} while ($true)


# Gather the necessary variables and save them to a file. The credential is stored in an encrypted format
$configuration = [pscustomobject]@{
    Server = $serverAddress
    Credential = $credential
    BasicUser = $basicUser
}
$configuration | Export-Clixml -Path (Join-Path -Path $path configuration.xml)

# Create our Scheduled Task trigger to run daily at 7am. Modify the 'At' parameter to change the time of day the task will run
$jobTrigger = New-JobTrigger -Daily -At (Get-Date -Hour 7)

# Find and delete this job if it already exists so we can modify and recreate the job using the same script
Get-ScheduledJob -Name 'Daily Milestone LPR Export' -ErrorAction SilentlyContinue | Unregister-ScheduledJob
Write-Information "Creating scheduled task. . ."
$job = Register-ScheduledJob -Name 'Daily Milestone LPR Export' -Trigger $jobTrigger -ArgumentList $path -ScriptBlock {
    param($path)
    $InformationPreference = "Continue"
    Start-Transcript -Path (Join-Path $path 'daily-lpr-export.log')
    $configuration = Import-Clixml -Path (Join-Path $path configuration.xml)
    $connected = $false
    try {
        Write-Host "$(Get-Date) - Connecting to $($configuration.Server) with user $($configuration.Credential.UserName). . ."
        Connect-ManagementServer -Server $configuration.Server -Credential $configuration.Credential -BasicUser:$configuration.BasicUser
        Write-Host "$(Get-Date) - Connected"
        $connected = $true
        $timeCondition = New-AlarmCondition -Target Timestamp -Operator GreaterThan -Value (Get-Date).AddDays(-7).ToUniversalTime()
        $typeCondition = New-AlarmCondition -Target Type -Operator Equals -Value 'LPR Event'
        Write-Host "$(Get-Date) - Retrieving LPR Events. . ."
        Get-EventLine -Conditions $timeCondition, $typeCondition -PageSize 1000 -Verbose | `
            Select Timestamp, SourceName, ObjectValue | `
            Export-Csv -Path (Join-Path $path lpr_export.csv) -NoTypeInformation
        Write-Host "$(Get-Date) - LPR data exported to $(Join-Path $path lpr_export.csv)"
    }
    finally {
        if ($connected) {
            Write-Host "$(Get-Date) - Disconnecting from $($configuration.Server)"
            Disconnect-ManagementServer
        }
        Stop-Transcript
    }
}
Write-Information "Scheduled Task $($job.Name) created with ID $($job.Id). It will now run daily at $($jobTrigger.At.Hour)"
if ((Read-Host -Prompt "Would you like to test this scheduled task now? (y/n)") -eq 'y') {
    Write-Information "Running the scheduled task - the log will be displayed when completed. . ."
    $job.Run()
    Get-Content -Path (Join-Path $path 'daily-lpr-export.log')
}