<# 
    Add hardware from a CSV file

    This sample shows how you can use Import-HardwareCsv to add and configure
    many cameras quickly.

    To use the sample, please login to your VMS with Connect-ManagementServer
    and consider changing which Recording Server the camera is added to. The
    first Recording Server returned by Get-RecordingServer will be used.

    The script below will first create a CSV file with a universal driver
    camera to use in the Import-HardwareCsv command. You would normally prepare
    your own CSV file instead. The CSV generated by this script will be placed
    in the current folder and will look like this:

    "HardwareName","HardwareAddress","UserName","Password","DriverNumber","GroupPath"
    "Universal Driver","http://wowzaec2demo.streamlock.net","root","pass","421","/New Cameras"
#>

$rows = @([pscustomobject]@{
    HardwareName = "Universal Driver"
    HardwareAddress = "http://wowzaec2demo.streamlock.net"
    UserName = 'root'
    Password = 'pass'
    DriverNumber = 421
    GroupPath = "/New Cameras"
})
$rows | Export-Csv .\test.csv -NoTypeInformation

$recorder = (Get-RecordingServer)[0]
$newHardware = Import-HardwareCsv -Path .\test.csv -RecordingServer $recorder

foreach ($hardware in $newHardware) {
    [pscustomobject]@{
        Name = $hardware.Name
        Id = $hardware.Id
        Address = $hardware.Address
        Cameras = $hardware.CameraFolder.Cameras.Count
    }
}