function Import-GpsCoordinates {
    <#
    .SYNOPSIS
        Updates the GPS coordinates of cameras in Milestone based on a CSV file with MAC addresses
        and the corresponding GPS coordinates.

    .DESCRIPTION
        This sample function allows you to override the default column names of "MAC" and 
        "Coordinates" if desired, and the coordinates are expected to be found in
        "latitude, longitude" format with no special characters except the separating comma.

    .PARAMETER Path
        The path to the source CSV file to use as input.

    .PARAMETER MacColumn
        Override the default column name to look for in the CSV file for the hardware MAC address.
        Default: MAC

	.PARAMETER CoordinateColumn
        Override the default column name to look for in the CSV file for the camera coordinates address.
        Default: Coordinates

    .EXAMPLE
        Import-GpsCoordinates -Path .\coordinates.csv

        Uses coordinates.csv to update the GisPoint property of all cameras who's parent Hardware object
        has a MAC address value found in the CSV file.
    #>
    [CmdletBinding()]
    param (
        # CSV file Path
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]
        $Path,
        # Optional: MAC Address column name. Default: MAC
        [Parameter()]
        [string]
        $MacColumn = "MAC",
        # Optional: Coordinate column name. Default: Coordinates
        [Parameter()]
        [string]
        $CoordinateColumn = "Coordinates"
    )
    
    process {
        $source = Import-Csv -Path $Path
        foreach ($hardware in Get-Hardware) {
            $mac = ($hardware | Get-HardwareSetting).MacAddress
            $matchingRow = $source | Where-Object $MacColumn -eq $mac
            if ($null -eq $matchingRow) { 
                Write-Warning "No row found in CSV file matching MAC address '$mac'"
                continue 
            }

            $lat, $long = $matchingRow.$CoordinateColumn -split ","
            $point = "POINT ($long $lat)"
            foreach ($camera in $hardware | Get-Camera) {
                $camera.GisPoint = $point
                $camera.Save()
            }
        }    
    }
}