## Activate PTZ Preset Positions
In this sample we will take advantage of a new feature introduced in MilestonePSTools v1.0.75,
Send-MipMessage. See the contents of Invoke-PtzPreset.ps1 for an example of how to trigger
a PTZ preset position or retrieve the current PTZ coordinates using Send-MipMessage.

In the following script, we'll find all cameras with at least one PTZ preset position, then
call Invoke-PtzPreset on each one. Then we'll take a snapshot of the camera, saving an image
to disk with the camera and preset position names in the file name.

```powershell
# Ask PowerShell to show us "Information" messages which are normally hidden/ignored
$InformationPreference = 'Continue'

# Select all cameras with at least one PTZ preset position
$cameras = Get-Hardware | Where-Object Enabled | Get-Camera | Where-Object { $_.Enabled -and $_.PtzPresetFolder.PtzPresets.Count -gt 0 }

# This is "dot sourcing" where we call an external script. In this case we're just
# loading the Invoke-PtzPreset function. We'll assume the Invoke-PtzPreset.ps1 file
# is in the same folder as this script.
. .\Invoke-PtzPreset.ps1

foreach ($camera in $cameras) {

    foreach ($ptzPreset in $camera.PtzPresetFolder.PtzPresets) {
        
        Write-Information "Moving $($camera.Name) to $($ptzPreset.Name) preset position"
        Invoke-PtzPreset -PtzPreset $ptzPreset -VerifyCoordinates

        Write-Information "Taking snapshot . . ."
        $snapshotParams = @{
            Live = $true
            Quality = 95
            Save = $true
            Path = "C:\demo"
            FileName = "$($camera.Name) -- $($ptzPreset.Name).jpg"
        }
        $null = $camera | Get-Snapshot @snapshotParams
    }
}
```