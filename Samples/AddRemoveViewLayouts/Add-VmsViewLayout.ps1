function Add-VmsViewLayout {
    <#
    .SYNOPSIS
        Adds a new view layout to a Milestone XProtect system.
    .DESCRIPTION
        Takes a CSV file that contains numbers representing panes and converts it into a new view layout. An image can also
        be specified for the icon of the view layout. Remove-VmsViewLayout (separate function) can be used to remove any
        custom view layouts that have been created with Add-VmsViewLayout.

        Use Excel, Google Sheets, LibreOffice Calc, or any other spreadsheet program that can save in CSV format to make it
        easier to create the necessary file. It is recommended to make the row heights and column widths in the spreadsheet
        application roughly the same size to get a good visual. You can use as many rows/columns as seems beneficial for
        your purposes of designing the layout. The script will convert everything to work properly in the Smart Client.
        
        Note that if the number of rows and columns is not the same, the view will be stretched to make them the same so it is
        recommended to use equal number of rows and columns. Also note that the number of rows/columns has no bearing on how
        the view will look in the Smart Client. If you can design the view layout you want with 10 rows/columns, then use
        that. If you need to use 20 rows/columns to get the granularity you need, then use 20.

        To create a layout, you need to put the same number in any cells that will be part of the same pane. The numbers in
        panes need to form squares/rectangles. If they don't, the layout will end up being wonky. Once finished, save the file
        as a CSV. Here is an ASCII "visual" of an example of what the spreadsheet might look like (the numbers in the first
        column are designating the row numbers, for visual purposes).

           | A | B | C | D | E | F | G | H | I | J |
        ---+---+---+---+---+---+---+---+---+---+---+
         1 | 1 | 1 | 1 | 2 | 2 | 2 | 2 | 2 | 2 | 2 |
        ---+---+---+---+---+---+---+---+---+---+---+
         2 | 1 | 1 | 1 | 2 | 2 | 2 | 2 | 2 | 2 | 2 |
        ---+---+---+---+---+---+---+---+---+---+---+
         3 | 1 | 1 | 1 | 2 | 2 | 2 | 2 | 2 | 2 | 2 |
        ---+---+---+---+---+---+---+---+---+---+---+
         4 | 3 | 3 | 3 | 2 | 2 | 2 | 2 | 2 | 2 | 2 |
        ---+---+---+---+---+---+---+---+---+---+---+
         5 | 3 | 3 | 3 | 4 | 4 | 4 | 5 | 5 | 5 | 5 |
        ---+---+---+---+---+---+---+---+---+---+---+
         6 | 3 | 3 | 3 | 4 | 4 | 4 | 5 | 5 | 5 | 5 |
        ---+---+---+---+---+---+---+---+---+---+---+
         7 | 3 | 3 | 3 | 4 | 4 | 4 | 5 | 5 | 5 | 5 |
        ---+---+---+---+---+---+---+---+---+---+---+
         8 | 3 | 3 | 3 | 6 | 6 | 6 | 6 | 6 | 6 | 6 |
        ---+---+---+---+---+---+---+---+---+---+---+
         9 | 3 | 3 | 3 | 6 | 6 | 6 | 6 | 6 | 6 | 6 |
        ---+---+---+---+---+---+---+---+---+---+---+
        10 | 3 | 3 | 3 | 6 | 6 | 6 | 6 | 6 | 6 | 6 |
        ---+---+---+---+---+---+---+---+---+---+---+
        
        The above "spreadsheet" would have CSV contents that looked like this:
        1,1,1,2,2,2,2,2,2,2
        1,1,1,2,2,2,2,2,2,2
        1,1,1,2,2,2,2,2,2,2
        3,3,3,2,2,2,2,2,2,2
        3,3,3,4,4,4,5,5,5,5
        3,3,3,4,4,4,5,5,5,5
        3,3,3,4,4,4,5,5,5,5
        3,3,3,6,6,6,6,6,6,6
        3,3,3,6,6,6,6,6,6,6
        3,3,3,6,6,6,6,6,6,6

        The above CSV contents will create a view layout that looks like this. Depending on what editor or PowerShell console you
        view the below in, it may be stretched vertically. That can be ignored. All view layouts in the Smart Client have a grid
        layout of 1000x1000.

        +---+---+---+---+---+---+---+---+---+---+
        |           |                           |
        +           +                           +
        |     1     |                           |
        +           +             2             +
        |           |                           |
        +---+---+---+                           +
        |           |                           |
        +           +---+---+---+---+---+---+---+
        |           |           |               |
        +           +           +               +
        |           |      4    |       5       |
        +           +           +               +
        |     3     |           |               |
        +           +---+---+---+---+---+---+---+
        |           |                           |
        +           +                           +
        |           |             6             |
        +           +                           +
        |           |                           |
        +---+---+---+---+---+---+---+---+---+---+
    .PARAMETER ViewLayoutName
        Specify the name the new view layout should have.
    .PARAMETER CsvPath
        Specify the path of the CSV file.
    .PARAMETER LayoutFolder
        Specify which view layout group the new view should be added to
    .PARAMETER IconPath
        Specify the path to an image that will be used for the icon. Supported formats are JPG, JPEG, GIF, BMP, PNG, TIF, TIFF,
        WMP, and ICO. The image will be resized to 16x16 pixels. If no image is specified, the icon will be a basic gray square.
    .PARAMETER Description
        Specify a description of the new view layout. This is optional.
    .EXAMPLE
        # Connect-Vms only required if not already connected
        Connect-Vms -ShowDialog -AcceptEula
        Add-VmsViewLayout -ViewLayoutName 'Sample View' -CsvPath 'C:\tmp\layout.csv' -LayoutFolder '16:9' -IconPath 'C:\tmp\view_icon.png'

        Adds a new view layout to the 16:9 folder
    .NOTES
        The software provided by Milestone Systems, Inc. (hereinafter referred to as "the Software") is provided on
        an "as is" basis, without any warranties or representations, express or implied, including but not limited to
        the implied warranties of merchantability, fitness for a particular purpose, or non-infringement.
        
        Warranty Disclaimer:
        The Software is provided without any warranty of any kind, whether expressed or implied. Milestone Systems, Inc.
        expressly disclaims all warranties, conditions, and representations, including but not limited to warranties of
        title, non-infringement, merchantability, or fitness for a particular purpose. The entire risk arising out of the
        use or performance of the Software remains with the user.
    
        Support Disclaimer:
        Milestone Systems, Inc. does not provide any support or maintenance services for the Software. The user acknowledges
        and agrees that Milestone Systems, Inc. shall have no obligation to provide any updates, bug fixes, or technical
        support for the Software, whether through telephone, email, or any other means.
    
        User Responsibility:
        The user acknowledges and agrees that they are solely responsible for the selection, installation, use, and results
        obtained from the Software. Milestone Systems, Inc. shall not be held liable for any errors, defects, or damages arising
        from the use or inability to use the Software, including but not limited to direct, indirect, incidental, consequential,
        or special damages.
    
        Indemnification:
        The user agrees to indemnify, defend, and hold harmless Milestone Systems, Inc. and its directors, officers, employees,
        and agents from any and all claims, liabilities, damages, losses, costs, and expenses (including reasonable attorneys' fees)
        arising out of or related to the user's use or misuse of the Software.

        By using the Software, the user acknowledges that they have read and understood this clause and agree to be bound by its terms.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $ViewLayoutName,
        [Parameter(Mandatory)]
        [ValidatePattern('\.(csv)$')]
        [string]
        $CsvPath,
        [Parameter(Mandatory)]
        [ValidateSet('4:3','16:9','4:3 Portrait','16:9 Portrait')]
        [string]
        $LayoutFolder,
        [Parameter()]
        [ValidatePattern('\.(jpg|jpeg|gif|bmp|png|tif|tiff|wmp|ico)$')] 
        [string]
        $IconPath,
        [Parameter(Mandatory=$false)]
        [string]
        $Description
    )

    $ms = Get-VmsManagementServer -ErrorAction SilentlyContinue
    if ([string]::IsNullOrEmpty($ms.Version)) {
        Write-Warning "Please connect to a Milestone XProtect system first."
        break
    }

    $layoutGroup = $ms.LayoutGroupFolder.LayoutGroups | Where-Object {$_.Name -eq $LayoutFolder}

    if (-not [string]::IsNullOrEmpty($IconPath)) {
        # Resize image so either the width or height (or both) is 16 pixels
        $oldImage = New-Object -TypeName System.Drawing.Bitmap -ArgumentList $IconPath
        $oldHeight = $oldImage.Height
        $oldWidth = $oldImage.Width

        if ($oldHeight -gt $oldWidth) {
            $ratio = $oldHeight / 16
            [int]$height =  $oldHeight / $ratio
            [int]$width = $oldWidth / $ratio
        }
        elseif ($oldWidth -gt $oldHeight) {
            $ratio = $oldWidth / 16
            [int]$width = $oldWidth / $ratio
            [int]$height = $oldHeight / $ratio
        }
        else {
            $ratio = $oldHeight / 16
            [int]$height =  $oldHeight / $ratio
            [int]$width = $oldWidth / $ratio
        }

        $bitmap = New-Object -TypeName System.Drawing.Bitmap -ArgumentList $width, $height
        $newImage = [System.Drawing.Graphics]::FromImage($bitmap)
        $newImage.DrawImage($oldImage, $(New-Object -TypeName System.Drawing.Rectangle -ArgumentList 0, 0, $width, $height))

        $dot = $iconPath.LastIndexOf(".")
        $extension = $iconPath.Substring($dot + 1,$iconPath.Length - $dot - 1)
        switch ($extension) {
            'jpg' {$extendedExtension = 'jpeg';break}
            'tif' {$extendedExtension = 'tiff';break}
            'ico' {$extendedExtension = 'icon';break}
            default {$extendedExtension = $extension}
        }

        $outputPath = "$($env:TEMP)\tmpImage.$($extension)"
        $bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::$extendedExtension)

        [string]$iconBase64 = [convert]::ToBase64String((Get-Content "$($env:TEMP)\tmpImage.$($extension)" -Raw -Encoding Byte))
        Remove-Item -Path "$($env:TEMP)\tmpImage.$($extension)" -Force
    } else {
        # If no image is provided for the icon, it is set to a plain, gray rectangle similar to the standard view icons but
        # just blank inside.
        $iconBase64 = 'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IArs4c6QAAAThJREFUOE+tk7FqwzAURe+TMHRz+w/t0vYP+iWmmz0YPBhCPOUfsiQEMhgPxlvWflAS2g4ldGkSRSbNK1KjEkwGx/QtQqB7dd59EgEgdCs2sq7ivyvJ9/2bSwE8z9uvVqs1AKZ+v/95gcFBCCG01svRaPQEYEODwcD20qaYGVJKKKU+hsPhLYAvyrLs0EZ8PGMJlFKv4/H4HsCaer1eawIA1mC32y0nk4kx2FCapobATMMYuak40+aejwbz6XT6AGBLSZJ0IVjkeW4IthTH8TmDJoGLyU1hXhTFL0EURS5EJzptpZnvgYhEXdeLsiwfrUEYhmzG07aEENBav1dVdWcNgiB4YeZrIroCIO37JjJU32bPzMKFzMxaSkl1Xb/NZrNnAMqkbERmbfMvTlH3//OZWt58LiJL8wMo2oQR1nRVYQAAAABJRU5ErkJggg=='
    }

    # Loop through each row in the CSV
    $csv = Get-Content -Path $CsvPath
    $dataArray = New-Object System.Collections.ArrayList

    for ($i = 0;$i -lt $csv.Length;$i++) {
        $null = $dataArray.Add($csv[$i].Split(','))
    }

    # Get unique numbers in CSV so we know how many view panes there are
    $flattend = $dataArray | ForEach-Object {$_}
    $unique = $flattend | Select-Object -Unique

    $xml = New-Object System.Xml.XmlDocument
    $viewLayout = $xml.CreateElement("ViewLayout")
    $viewLayout.SetAttribute("ViewLayoutType","VideoOS.RemoteClient.Application.Data.ViewLayouts.ViewLayoutCustom, VideoOS.RemoteClient.Application")
    $viewLayout.SetAttribute("ViewLayoutGroupId",$layoutGroup.Id)
    $null = $xml.AppendChild($viewLayout)

    $viewLayoutIcon = $xml.CreateElement("ViewLayoutIcon")
    $viewLayoutIcon.InnerText = $iconBase64
    $null = $viewLayout.AppendChild($viewLayoutIcon)

    $rows = $csv.Length
    $columns = [math]::Round($csv[0].Length / 2)

    
    $unique | ForEach-Object {
        $valueToFind = $_
        $locations = @()
        for ($i = 0; $i -lt $dataArray.Count; $i++) {
            for ($j = 0; $j -lt $dataArray[0].Count; $j++) {
                if ($dataArray[$i][$j] -eq $valueToFind) {
                    $locations += "$j,$i" # Need to list it as "$j,$i" because $j is x-coord and $i is y-coord
                }
            }
        }

        $xCoord = [math]::Round([int]($locations[0].Split(",")[0]) * (1000 / $columns)) # Milestone views have 1000 points on X axis
        $yCoord = [math]::Round([int]($locations[0].Split(",")[1]) * (1000 / $rows)) # Milestone views have 1000 points on Y axis
        $firstX = [int]($locations[0].Split(",")[0])
        $firstY = [int]($locations[0].Split(",")[1])
        $lastX = [int]($locations[-1].Split(",")[0])
        $lastY = [int]($locations[-1].Split(",")[1])
        $widthValue = [math]::Round(($lastX - $firstX + 1) * (1000 / $columns)) # Milestone views have 1000 points on X axis
        $heightValue = [math]::Round(($lastY - $firstY + 1) * (1000 / $rows)) # Milestone views have 1000 points on X axis

        $viewItems = $xml.CreateElement("ViewItems")

        $viewItem = $xml.CreateElement("ViewItem")
        $position = $xml.CreateElement("Position") 
        $size = $xml.CreateElement("Size")    

        $x = $xml.CreateElement("X")
        $x.InnerText = $xCoord
        $null = $position.AppendChild($x)

        $y = $xml.CreateElement("Y")
        $y.InnerText = $yCoord
        $null = $position.AppendChild($y)

        $posWidth = $xml.CreateElement("Width")
        $posWidth.InnerText = $widthValue
        $null = $size.AppendChild($posWidth)

        $posHeight = $xml.CreateElement("Height")
        $posHeight.InnerText = $heightValue
        $null = $size.AppendChild($posHeight)

        $null = $viewItem.AppendChild($position)
        $null = $viewItem.AppendChild($size)
        $null = $viewItems.AppendChild($viewItem)

        $null = $viewLayout.AppendChild($viewItems)
    }
    $null = $xml.AppendChild($viewLayout)

    $null = $layoutGroup.LayoutFolder.AddLayout($ViewLayoutName,$Description,$xml.OuterXml)
}