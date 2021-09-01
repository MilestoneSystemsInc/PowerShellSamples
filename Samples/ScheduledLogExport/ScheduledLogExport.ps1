#Requires -RunAsAdministrator
#Requires -Modules MilestonePSTools, MipSdkRedist, PSScheduledJob

# Collect & test Management Server login details and persist to disk
Connect-ManagementServer -ShowDialog -Force -AcceptEula -ErrorAction Stop
$loginSettings = Get-LoginSettings
$authType = if ($loginSettings.IsBasicUser) { 'Basic' } else { 'Negotiate' }
$credential = $loginSettings.CredentialCache.GetCredential($loginSettings.Uri, $authType)
if ($credential.UserName -eq [string]::Empty) {
    $credential = $null
}
else {
    $credential = [pscredential]::new("$(if (![string]::IsNullOrWhiteSpace($credential.Domain)) {"$($credential.Domain)\"})$($credential.UserName)", $credential.SecurePassword)
}
$connectParams = @{
    ServerAddress = $loginSettings.Uri
    Credential = $credential
    BasicUser = $loginSettings.IsBasicUser
    SecureOnly = $loginSettings.SecureOnly
    AcceptEula = $true
}
$connectParams | Export-Clixml -Path $PSScriptRoot\connection.xml -Force
Disconnect-ManagementServer




# Setup scheduled job using PSScheduledJob module commands
$jobOptions = New-ScheduledJobOption -RequireNetwork -MultipleInstancePolicy IgnoreNew
$jobTrigger = New-JobTrigger -Daily -At (Get-Date -Hour 6 -Minute 0 -Second 0)
$jobParams = @{
    Name = 'Daily Log Export'
    ScheduledJobOption = $jobOptions
    Trigger = $jobTrigger
    RunNow = $true
    ArgumentList = $PSScriptRoot
}
Get-ScheduledJob -Name $jobParams.Name -ErrorAction Ignore | Unregister-ScheduledJob -Force -ErrorAction Stop
Register-ScheduledJob @jobParams -ScriptBlock {
    param([string]$WorkingDirectory)
    try {
        # Transcript file is overwritten after every execution of the job so it always contains logs from the last run and does not grow indefinitely
        Start-Transcript -Path $WorkingDirectory\ScheduledLogExport.log
        $reportsFolder = New-Item -Path (Join-Path $WorkingDirectory 'exports\') -ItemType Directory -Force | Select-Object -ExpandProperty FullName
        Write-Host 'Cleaning up exports older than 30 days'
        Get-ChildItem -Path "$reportsFolder\Log-Export_*.csv" | Where-Object CreationTime -lt (Get-Date).AddDays(-30) | Remove-Item -Verbose

        # Import Management Server connection details from disk
        $connectParams = Import-Clixml -Path $WorkingDirectory\connection.xml
        Write-Host "Connecting to $($connectParams.ServerAddress). . ."
        Connect-ManagementServer @connectParams -Verbose
        
        $csvPath = Join-Path $reportsFolder "Log-Export_$(Get-Date -Format FileDateTime).csv"
        Write-Host "Running Get-Log and saving results to $csvPath"
        Get-Log -LogType Audit -BeginTime (Get-Date).Date.AddDays(-1) -EndTime (Get-Date).Date | Export-Csv -Path $csvPath -NoTypeInformation
    }
    catch {
        Write-Error $_
    }
    finally {
        $loadedModules = Get-Module | Select-Object Name, Version | Out-String
        Write-Host "Loaded modules and versions: $loadedModules"
        Write-Host 'Finished. Disconnecting from Management Server.'
        Disconnect-ManagementServer
        Stop-Transcript
    }
}