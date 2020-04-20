<# 
    Add hardware using the Universal Driver

    This sample shows how you can add and configure an RTSP stream.
    The RTSP stream in this sample is hosted by Wowza Streaming Engine at
    https://www.wowza.com/html/mobile.html

    To use the sample, please login to your VMS with Connect-ManagementServer
    and consider changing which Recording Server the camera is added to. It
    will be added to the first Recording Server returned by Get-RecordingServer
#>

# Retrieve the first Recording Server
$recorder = Get-RecordingServer | Select-Object -First 1
$hardwareParams = @{
    Address = 'http://wowzaec2demo.streamlock.net'
    DriverId = 421
    GroupPath = '/Add-Hardware Demo'
}

try {
    $hardware = $recorder | Add-Hardware @hardwareParams
}
catch {
    # If the hardware fails to add for some reason, lets quit the script
    throw
}

# Select the camera device at index 0 on the new hardware and configure it
$camera = $hardware | Get-Camera -Channel 0
$camera | Set-CameraSetting -Stream -StreamNumber 0 -Name FPS -Value 25
$camera | Set-CameraSetting -Stream -StreamNumber 0 -Name StreamingMode -Value 'RTP over RTSP (TCP)'
$camera | Set-CameraSetting -Stream -StreamNumber 0 -Name ConnectionURI -Value 'vod/mp4:BigBuckBunny_115k.mov'

# Select the microphone, configure it, and enable it
$microphone = $hardware | Get-Microphone -Channel 0
$microphone | Set-MicrophoneSetting -Stream -StreamNumber 0 -Name Codec -Value AAC
$microphone | Set-MicrophoneSetting -Stream -StreamNumber 0 -Name ConnectionURI -Value 'vod/mp4:BigBuckBunny_115k.mov'
$microphone | Set-MicrophoneSetting -Stream -StreamNumber 0 -Name StreamingMode -Value 'RTP over RTSP (TCP)'
$microphone.Enabled = $true; $microphone.Save()
# Create a device group for the microphone and add the mic to it
$group = Add-DeviceGroup -DeviceCategory Microphone -Path '/New Mics'
Add-DeviceGroupMember -DeviceGroup $group -DeviceCategory Microphone -DeviceId $microphone.Id

# Lets just show some information about the newly added device at the end 
[pscustomobject]@{
    Camera = $camera.Name
    Id = $camera.Id
    Uri = ($camera | Get-CameraSetting -Stream -StreamNumber 0).ConnectionURI
}