#Requires -RunAsAdministrator
#Requires -Modules 'MilestonePSTools'

# The Requires statements ensure the user runs the script as Administrator, and has the MilestonePSTools module installed

# Instead of setting -ErrorAction 'Stop' in every function call, we set ErrorActionPreference which applies to the whole script
# This way, we stop the script if something goes wrong instead of proceeding with incomplete data
$ErrorActionPreference = "Stop"


function Get-ConnectionInfo {
    <#
    .SYNOPSIS
        Capture Milestone server address and credentials, and verify it before returning that
        data to the caller.
    #>    
    while ($true) {
        $server = Read-Host -Prompt "Server address"
        $credential = Get-Credential -Message "Milestone User Credential"
        $basicUser = (Read-Host -Prompt "Basic user? (y/n)") -eq 'y'
        
        try {
            Write-Information "Testing credentials for user $($credential.UserName) on server $server. . ."
            Connect-ManagementServer -Server $server -Credential $credential -BasicUser:$basicUser
            Write-Information "Successfully connected to Management Server"
            Disconnect-ManagementServer
            break
        }
        catch {
            Write-Warning "Error: $($_.CategoryInfo.Reason). Please try again. . ."
        }
    }

    @{
        Server = $server
        Credential = $credential
        BasicUser = $basicUser
    }
}

# Get working Milestone server address and credentials
$config = Get-ConnectionInfo

# Get seconds between snapshots or the snapshot interval
# Tests the user-input to make sure it's a valid integer before continuing
while ($true) {
    $interval = Read-Host -Prompt "How many seconds between snapshots"
    $intValue = 0
    if ([int]::TryParse($interval, [ref] $intValue) -and $intValue -ge 1) {
        $config.IntervalSeconds = $intValue
        break
    }
    else {
        Write-Warning "Value must be an integer greater than 0. Please try again. . ."
    }
}

# Let the user select which cameras will be used. Note this gets the raw camera ids and even though
# you can add cameras using a device group, only the cameras in that group at the time this script
# is run will be included in the snapshot collection when the scheduled job is running.
Connect-ManagementServer -Server $config.Server -Credential $config.Credential -BasicUser:$config.BasicUser
do {
    [array]$cameraIds = (Select-Camera -AllowFolders -AllowServers -RemoveDuplicates -OutputAsItem).FQID.ObjectId
} while ($cameraIds.Count -le 0)
Disconnect-ManagementServer
$config.CameraIds = $cameraIds

# Save the server address, credentials and settings to an XML file.
# PowerShell encrypts the password in the credential so that only the current
# user can actually decrypt it.
$config | Export-Clixml -Path $PSScriptRoot\config.xml

# Check if the scheduled job has previously been created, and delete it if so.
$jobName = "Milestone Snapshot Task"
Get-ScheduledJob -Name $jobName -ErrorAction Ignore | Unregister-ScheduledJob -Force

# Create / Recreate the scheduled task with a trigger on system startup.
$trigger = New-JobTrigger -AtStartup

# If the job is already running and is triggered again, ignore the new instance. Require network as well
$options = New-ScheduledJobOption -MultipleInstancePolicy IgnoreNew -RequireNetwork

# Create the scheduled job. This appears in Task Scheduler in Windows under Microsoft/Windows/PowerShell/ScheduledJobs
# We'll run the job immediately upon creation so that the task starts running in the background immediately
$null = Register-ScheduledJob -Name $jobName -ScheduledJobOption $options -Trigger $trigger -RunNow -ArgumentList $PSScriptRoot -ScriptBlock {
    param([string]$WorkingDirectory)
    $ErrorActionPreference = "Stop"
    function Write-Log {
        <#
        .SYNOPSIS
            We want the transcript to include a timestamp for each line to make it easier to understand when
            and how long operations are taking. So all Write-Host commands will use Write-Log instead.

            Also, normally we'd use Write-Information but a bug in PowerShell means the transcript does not
            include anything from the Information stream. So Write-Host it is.
        #>
        param([string]$Message)
        Write-Host "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff") - $Message"
    }

    try {
        Start-Transcript -Path (Join-Path -Path $WorkingDirectory -ChildPath job.log) -Force

        if (-not (Test-Path $WorkingDirectory\snapshots)) {
            Write-Log "Creating missing snapshots subfolder"
            $null = New-Item -Path $WorkingDirectory\snapshots -ItemType Directory -Force
        }

        Write-Log "Importing configuration"
        $config = Import-Clixml -Path $WorkingDirectory\config.xml
        
        $connected = $false
        Write-Log "Connecting to Management Server at $($config.Server) with user $($config.Credential.UserName). . ."
        Connect-ManagementServer -Server $config.Server -Credential $config.Credential -BasicUser:$config.BasicUser
        Write-Log "Connected"
        $connected = $true
                
        Write-Log "Retrieving snapshots every $($config.IntervalSeconds) seconds"
        $interval = New-TimeSpan -Seconds $config.IntervalSeconds
        $stopwatch = [diagnostics.stopwatch]::new()
        while ($true) {
            $stopwatch.Restart()
            foreach ($id in $config.CameraIds) {
                $camera = Get-Camera -Id $id
                $folder = Join-Path -Path $WorkingDirectory -ChildPath snapshots\$($camera.Name)\
                if (-not (Test-Path -Path $folder)) {
                    Write-Log "Creating subfolder for camera $($camera.Name) at $folder"
                    $null = New-Item -Path $folder -ItemType Directory -Force
                }
                Write-Log "Getting snapshot from $($camera.Name)"
                $null = $camera | Get-Snapshot -Live -Save -Path $folder -UseFriendlyName
            }

            # Figure out how much we need to sleep in order to aim for the user-defined interval.
            # So subtract the time we spent generating snapshots from the desired interval, and sleep
            # for the difference. If the snapshots took longer than the interval time, then we'll just
            # skip the delay and repeat the process immediately
            $delay = $interval - $stopwatch.Elapsed
            if ($delay.TotalMilliseconds -gt 0) {
                Write-Log "Completed cycle in $($stopwatch.Elapsed.TotalSeconds) seconds. Sleeping for $($delay.TotalMilliseconds)ms"
                Start-Sleep -Milliseconds $delay.TotalMilliseconds
            }
            else {
                Write-Log "WARNING: Completed cycle in $($stopwatch.Elapsed.TotalSeconds) seconds. This is longer than the desired interval of $($interval.TotalSeconds)"
            }
        }
    }
    finally { 
        if ($connected) {
            Write-Log "Logging out of Management Server"
            Disconnect-ManagementServer
        }
        Stop-Transcript
    }
}
