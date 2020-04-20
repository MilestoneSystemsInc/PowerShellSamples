<# 
    Extend Get-CameraReport by performing a Test-NetConnection against any
    cameras with the state 'Not Responding' in the VMS.

    To use the sample, please login to your VMS with Connect-ManagementServer
    and ensure you are running the script from a PC with direct network access
    to the cameras. If the cameras are segmented from the rest of the network
    you may need to run this script on your Recording Server(s) or Management
    Server.

    Finally, the results in this script are piped to Out-GridView. You may wish
    to send the results to Export-Csv instead.
#>

$report = Get-CameraReport

foreach ($row in $report) {
    $networkState = 'Online'
    
    if ($row.State -eq 'Not Responding') {
        $uri = [Uri]$row.Address
        $reachable = Test-NetConnection -ComputerName $uri.Host -Port $uri.Port -InformationLevel Quiet
        if (-not $reachable) {
            $networkState = 'Offline'
        }
    }

    $row | Add-Member -MemberType NoteProperty -Name 'NetworkState' -Value $networkState
}

$report | Out-GridView