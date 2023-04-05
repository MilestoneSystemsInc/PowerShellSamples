function Set-MilestoneNames
{
    <#
    .SYNOPSIS
        Allows user to export enabled hardware and camera names to CSV. Once new names are added, allows user to import the updated names from the CSV.

    .DESCRIPTION
        Steps for use (if you are familiar with PowerShell functions, skip to step #):
        1. Once opening Set-MilestoneNames.ps1 in Windows PowerShell ISE, click the green "Run Script" arrow (or just press F5)
        2. Run the command in the first example below to Export the CSV.  The path can be changed if desired.
        3. If the machin this script is running on does not have Excel, copy the CSV file to a machine with Excel installed.
        4. For any hardware or cameras where the name needs to be changed, enter the new name in the "NewHardwareName" or
        "NewCameraName" column.  If the name doesn't need to be changed, don't do anything for that row.
            a. Do NOT change any of the other data.
        5. Copy the CSV back to the machine this script is running on (if it was copied to another machine).
        6. Run the command in the second example below to Import the new names.  Make sure the path points to the CSV file.

    .EXAMPLE
        Set-MilestoneNames -Export -CsvPath "$($env:USERPROFILE)\Desktop\MilestoneNames.csv"
        
        Exports a CSV file named MilestoneNames.csv to the users desktop.  This file contains all of the enabled hardware and camera named
    .EXAMPLE
        Set-MilestoneNames -Import -CsvPath "$($env:USERPROFILE)\Desktop\MilestoneNames.csv"
        
        Imports a CSV file that contains updated hardware or camera names.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [switch]
        $Import,
        [Parameter(Mandatory=$false)]
        [switch]
        $Export,
        [Parameter(Mandatory=$true)]
        [string]
        $CsvPath
    )

    if ($Import -eq $false -and $Export -eq $false -or ($Import -eq $true -and $Export -eq $true))
    {
        Write-Host "Either -Import or -Export needs to be specified." -ForegroundColor Red
        Break
    }

    Connect-ManagementServer -ShowDialog -Force
    $data = New-Object System.Collections.Generic.List[PSCustomObject]

    if ($Export)
    {
        foreach ($hw in Get-VmsHardware | Where-Object Enabled)
        {
            $row = [PSCustomObject]@{
                Type = "Hardware"
                CurrentHardwareName = $hw.Name
                NewHardwareName = ""
                HardwareId = $hw.Id
                CurrentCameraName = ""
                NewCameraName = ""
                CameraId = ""
            }
            $data.Add($row)

            foreach ($cam in $hw | Get-VmsCamera)
            {
                $row = [PSCustomObject]@{
                    Type = "Camera"
                    CurrentHardwareName = ""
                    NewHardwareName = ""
                    HardwareId = ""
                    CurrentCameraName = $cam.Name
                    NewCameraName = ""
                    CameraId = $cam.Id
                }
                $data.Add($row)
            }
        }
        $data | Export-Csv -Path $CsvPath -NoTypeInformation
    }

    if ($Import)
    {
        $csv = Import-Csv -Path $CsvPath
        
        foreach ($item in $csv)
        {
            if ($item.Type -eq "Hardware" -and -not [string]::IsNullOrEmpty($item.NewHardwareName))
            {
                Get-VmsHardware -HardwareId $item.HardwareID | Set-VmsHardware -Name $item.NewHardwareName
            }

            if ($item.Type -eq "Camera" -and -not [string]::IsNullOrEmpty($item.NewCameraName))
            {
                Get-VmsCamera -Id $item.CameraId | Set-VmsCamera -Name $item.NewCameraName
            }
        }
    }
}