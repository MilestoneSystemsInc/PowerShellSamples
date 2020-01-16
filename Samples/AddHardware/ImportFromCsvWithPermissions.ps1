# This sample demonstrates one way you can import cameras from a CSV file and
# grant some basic read permissions to a pipe-delimited set of roles. Errors
# will be logged as warnings to the console and any failed records will be
# saved in the $failed variable.
#
# It is assumed you are already logged in to your VMS, and you have a CSV file
# prepared which resembles the example below:
#
# Address,UserName,Password,RecordingServer,Name,Group,Roles
# "http://192.168.1.100","root","pass","Recorder1","Driveway","/Outdoor","Operators|Security"


$newHardwareRows = Import-Csv -Path .\newhardware.csv
$failed = New-Object System.Collections.Generic.List[pscustomobject]
foreach ($record in $newHardwareRows)
{
    try {
        $recorder = Get-RecordingServer -Name $record.RecordingServer
        $params = @{
            Address = $record.Address
            UserName = $record.UserName
            Password = $record.Password
            Name = $record.Name
            GroupPath = $record.Group
        }
        $hw = $recorder | Add-Hardware @params -Enabled

        foreach ($camera in $hw | Get-Camera) {
            foreach ($roleName in $record.Roles.Split('|')) {
                $acl = $camera | Get-DeviceAcl -RoleName $roleName
        
                $acl.SecurityAttributes["GENERIC_READ"] = "True"
                $acl.SecurityAttributes["VIEW_LIVE"] = "True"
                $acl.SecurityAttributes["PLAYBACK"] = "True"
                $acl.SecurityAttributes["PTZ_CONTROL"] = "True"
                $acl.SecurityAttributes["READ_BOOKMARKS"] = "True"
                $acl.SecurityAttributes["READ_EVIDENCE_LOCK"] = "True"
                $acl.SecurityAttributes["READ_SEQUENCES"] = "True"

                $acl | Set-DeviceAcl
            }
        }
    }
    catch {
        Write-Warning "Error adding $($record.Address): $($_.Message)"
        $failed.Add($record)
    }
}