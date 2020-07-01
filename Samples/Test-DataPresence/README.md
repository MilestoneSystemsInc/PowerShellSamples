## Test Data Presence

In this cmdlet (or group of cmdlets) we test for the presence of data between a given StartTime
and EndTime for devices of any type including cameras, microphones, speakers and metadata.

The method used to test for the presence of data is to retrieve a snapshot at the given StartTime
and check the value of the DateTime property. If it's between StartTime and EndTime, we know that
there's at least _some_ data within the given span of time.

Thanks to the behavior, and additional properties available on playback data, we can determine
from that single snapshot whether any data is available in the entire span of time. Whether the
snapshot is for a camera, microphone, speaker, or metadata.

When calling "GetNearest([DateTime])" on a data source in MIP SDK, a frame of data will be
returned if anything is available, and it will be some time before or after the given DateTime
value. Along with the data will be values indicating the DateTime value of the next available
frame of data, and the previous frame of data (if available).

So if the data returned is _before_ the StartTime, and the NextDateTime value is between
StartTime and EndTime, then we can safely say there is data available in that time span.

And if the nearest frame is _after_ the EndTime, we know that the nearest image to StartTime is
after the EndTime and thus there is no data present between StartTime and EndTime.

The Test-DataPresence cmdlet accepts a configuration item of any of the four data types, and
passes the request on to more specific functions like Test-VideoPresence, Test-AudioPresence, or
Test-MetadataPresence. But all three of these functions work very similarly - each making use of
the matching data source classes from MIP SDK to query the media database.

```powershell
$InformationPreference = 'Continue'
$server = Read-Host -Prompt "Server Address"
$credential = Get-Credential

do {
    $isBasic = Read-Host -Prompt "Basic user? (y/n)"
} while ('y', 'n' -notcontains $isBasic)

try {
    Write-Information "Validating credentials and camera selection before we register the scheduled job"
    Write-Information "Connecting to $server as $username"
    $connected = $false
    Connect-ManagementServer -Server $server -Credential $credential -BasicUser:($isBasic -eq 'y')
    Write-Information "Connected"
    $connected = $true

    foreach ($lock in Get-EvidenceLock) {
        $lockHasData = $false
        $cameras = $lock.DeviceIds | Foreach-Object { try { Get-Camera -Id $_ } catch { } }
        foreach ($camera in $cameras) {
            $dataExists = $camera | Test-DataPresence -StartTime $lock.StartTime -EndTime $lock.EndTime
            if ($dataExists) {
                $lockHasData = $true
                break;
            }
        }

        if (-not $lockHasData) {
            $lock
        }
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
```
