## Scheduled Video Export
In this sample we will use the Register-ScheduledJob cmdlet included in PowerShell to create a
scheduled task in Windows which runs our export script every day at midnight.

The sample below can be copied and pasted into an elevated PowerShell or PowerShell ISE instance.
Make sure to run PowerShell as Administrator, otherwise the Register-ScheduledJob will throw an
error.

The script will collect the VMS address, credentials, and ask you for a camera selection keyword.
If you want to export all cameras with the word "Elevator" in the name, you can enter that as a
keyword. They keyword is case-insensitive. You will then be asked for a destination path to save
exports. Each export will be stored in a date-stamped subfolder here. And before we register the
scheduled job, the credentials and camera selection will be validated. If a connection cannot be
made or there are no cameras matching the provided keyword, the scheduled job will not be created.

The $expandingString bit may look somewhat foreign. What we're doing here is creating a script
block where specific variables are expanded into their actual values before being stored in the
scheduled job. This is allowing us to pass the answers from the top of the script into the body
of the scriptblock called by the scheduled job.

By doing it this way, we're able to ask you for your VMS credentials without exposing your password
or having to persist it to disk in encrypted form. Your password is collected as a secure string,
then converted to a long string that can only be decrypted by the Windows user with which you're
executing the script.

```powershell
$InformationPreference = 'Continue'
$server = Read-Host -Prompt "Server Address"
$username = Read-Host -Prompt "Username"
$password = Read-Host -Prompt "Password" -AsSecureString | ConvertFrom-SecureString

do {
    $isBasic = Read-Host -Prompt "Basic user? (y/n)"
} while ('y', 'n' -notcontains $isBasic)

$keyword = Read-Host -Prompt "Keyword for camera selection"

do {
    $destination = Read-Host -Prompt "Export path"
} while (-not (Test-Path -Path $destination))

try {
    Write-Information "Validating credentials and camera selection before we register the scheduled job"
    Write-Information "Connecting to $server as $username"
    $connected = $false
    Connect-ManagementServer -Server $server -Credential ([pscredential]::new($username, ($password | ConvertTo-SecureString))) -BasicUser:($isBasic -eq 'y')
    Write-Information "Connected"
    $connected = $true

    Write-Information "Verifying there is at least one camera with a name matching keyword '$keyword'"
    $cameras = Get-Hardware | Where-Object Enabled | Get-Camera | Where-Object { $_.Enabled -and $_.Name -like "*$keyword*" }
    if ($null -eq $cameras) {
        throw "No cameras found matching keyword '$keyword'"
    }
    else {
        Write-Information "Identified $($cameras.Count) cameras matching keyword '$keyword'"
    }
}
catch {
    throw
}
finally {
    if ($connected) {
        Disconnect-ManagementServer
    }
}


$expandingString = "
    `$pass = '$password' | ConvertTo-SecureString
    `$cred = [pscredential]::new('$username', `$pass)
    `$isBasic = '$isBasic' -eq 'y'
    Connect-ManagementServer -Server $server -Credential `$cred -BasicUser:`$isBasic
    `$cameras = Get-Hardware | Where-Object Enabled | Get-Camera | Where-Object { `$_.Enabled -and `$_.Name -like '*$keyword*' }

    `$start = (Get-Date -Hour 13 -Minute 0 -Second 0).AddDays(-1)
    `$end = (Get-Date -Hour 15 -Minute 0 -Second 0).AddDays(-1)

    Start-Export -CameraIds `$cameras.Id -StartTime `$start -EndTime `$end -Format DB -Path ""$destination\`$(`$start.ToString('yyyy-MM-dd'))""

    Disconnect-ManagementServer
"

$script = [scriptblock]::Create($expandingString)
$trigger = New-JobTrigger -Daily -DaysInterval 1 -At (Get-Date -Hour 0 -Minute 0)
Register-ScheduledJob -Name "Automated Export Example" -ScriptBlock $script -Trigger $trigger
```