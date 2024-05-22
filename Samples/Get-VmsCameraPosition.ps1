function Get-VmsCameraPosition {
    <#
    .SYNOPSIS
        Returns position data (latitude, longitude, field of view, etc.) for each camera in the system
    .DESCRIPTION
        For each camera in the system, this function returns the camera name, latitude, longitude, Field of View (in degrees),
        the direction the camera is facing both in Cardinal (i.e. N, NW, SE, etc.) and Degrees, and depth of the Field of View (in feet).

        If latitude and longitude are empty, then the rest of the values are ignored.
    .EXAMPLE
        Get-VmsCameraPosition
        Outputs the following information

        CamName                        Latitude           Longitude         FOV (Degrees) Direction (Cardinal) Direction (Degrees) Depth (Feet)
        -------                        --------           ---------         ------------- -------------------- ------------------- ------------
        Axis M1125 - Camera 1          45.4170433700828   -122.732230489572        150.74 N                                   1.43        27.72
        Axis P3265-LVE - Camera 1      34.4257539305559   -117.131595665415            72 NE                                  46.3       231.89
        Canon VB-S30D - Camera 1       12.000030728223    -11.0000179326625            72 N                                      0        65.62
    #>

    $camInfo = New-Object System.Collections.Generic.List[PSCustomObject]

    $directionArray = @(
        "N"
        "NNE"
        "NE"
        "ENE"
        "E"
        "ESE"
        "SE"
        "SSE"
        "S"
        "SSW"
        "SW"
        "WSW"
        "W"
        "WNW"
        "NW"
        "NNW"
    )

    foreach ($cam in Get-VmsCamera)
    {
        $gisPoint = $cam.GisPoint
        if ($gisPoint.Substring(7, $GisPoint.Length - 8) -match "[0-9]")
        {
            $long = $gisPoint.Substring(7, $GisPoint.Length - 8).Split(" ")[0]
            $lat = $gisPoint.Substring(7, $GisPoint.Length - 8).Split(" ")[1]
        } else
        {
            $long = $null
            $lat = $null
        }

        if ($gisPoint -eq "POINT EMPTY")
        {
            $fov = $null
            $directionCardinal = $null
            $directionDegrees = $null
            $depth = $null
        } else
        {
            $fov = $cam.CoverageFieldOfView * 360
            
            # Sometimes degrees is stored as 0 to 360 and sometimes it is stored as -180 to 180.
            # Both need to be accounted for.
            if ($cam.CoverageDirection -ge 0)
            {
                $directionDegrees = $cam.CoverageDirection * 360
            } elseif ($cam.CoverageDirection -lt 0)
            {
                $directionDegrees = 360 + ($cam.CoverageDirection * 360)
            }

            if (($cam.CoverageDirection * 360) -ne 360)
            {
                $index = [math]::Floor($directionDegrees / 22.5)
                $directionCardinal = $directionArray[$index]
            } elseif (($cam.CoverageDirection * 360) -eq 360)
            {
                $directionCardinal = "N"
            } else
            {
                $directionCardinal = $null
            }
            $depth = $cam.CoverageDepth * 3.28084
        }

        $row = [PSCustomObject]@{
            CamName = $cam.Name
            Latitude = $lat
            Longitude = $long
            "FOV (Degrees)" = $fov
            "Direction (Cardinal)" = $directionCardinal
            "Direction (Degrees)" = if ($null -ne $directionDegrees) {[math]::Round($directionDegrees,2)} else {$null}
            "Depth (Feet)" = if ($null -ne $depth) {[math]::Round($depth,2)} else {$null}
        }
        $camInfo.Add($row)
    }
    $camInfo
}