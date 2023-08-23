function Export-VmsLotsOfVideo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $RecordingServerId,
        [Parameter(Mandatory)]
        [string]
        $NewStoragePath
    )
    
    process {
        $rsService = Get-Service -Name 'Milestone XProtect Recording Server' -ErrorAction SilentlyContinue
        if ([string]::IsNullOrEmpty($rsService))
        {
            Write-Warning "This script needs to be run on the Recording Server containing the video. Please try again."
            Break
        } elseif ($rsService.Status -eq 'Running') {
            Write-Warning "The Recording Server service must be stopped before running this script. Please try again."
            Break
        }
        
        if ((Get-ChildItem -Path $NewStoragePath -Force -ErrorAction SilentlyContinue | Measure-Object).Count -ne 0)
        {
            Write-Warning "'NewStoragePath' directory is not empty. Please use an empty directory."
            Break
        } else {
            $null = New-Item -Path $NewStoragePath -ItemType Directory -Force
        }

        $recId = Select-Xml -Path "C:\ProgramData\Milestone\XProtect Recording Server\RecorderConfig.xml" -XPath '/recorderconfig/recorder/id' | ForEach-Object {$_.node.InnerXml}
        if ($RecordingServerId -ne $recId)
        {
            Write-Warning "Specified Recording Server ID is not the same as this recording servers ID. Please verify the ID and try again."
            Break
        }
        
        if ($null -eq (Get-VmsManagementServer -ErrorAction SilentlyContinue))
        {
            Write-Warning "Please connect to a Milestone system before continuing."
            Break
        }
        $cams = Select-Camera -AllowFolders

        if ($null -eq $cams)
        {
            Write-Warning "No cameras selected. Please try again."
            Break
        }

        $wrongCams = $false
        foreach ($cam in $cams)
        {
            $rec = Get-ConfigurationItem -ConfigurationItem (Get-ConfigurationItem -Id $cam.Id -Path $cam.Path -ParentItem) -ParentItem
            if (($rec.Properties | Where-Object Key -eq Id).Value -ne $recId)
            {
                Write-Warning "Camera '$($cam.Name)' is not part of this Recording Server. Please ensure all selected cameras are part of this Recording Server."
                $wrongCams = $true
            }
        }

        if ($wrongCams)
        {
            Break
        }

        $storageInfo = New-Object System.Collections.Generic.List[PSCustomObject]
        $liveDBObject = Get-RecordingServer -Id ($rec.Properties | Where-Object Key -eq Id).Value | Get-VmsStorage

        foreach ($liveDB in $liveDBObject)
        {
            $row = [PSCustomObject]@{
                StorageId   = $liveDB.Id
                StoragePath = "$($liveDB.DiskPath)\$($liveDB.Id)"
            }
            $storageInfo.Add($row)

            $archiveDBObject = $liveDB | Get-VmsArchiveStorage

            foreach ($archiveDB in $archiveDBObject)
            {
                $row = [PSCustomObject]@{
                    StorageId   = $archiveDB.Id
                    StoragePath = "$($archiveDB.DiskPath)\$($archiveDB.Id)"
                }
                $storageInfo.Add($row)
            }
        }

        $timeRange = Show-DateTimeSelector

        $guidPattern = [regex]::new("^[^_]+(?=_)")
        $dateTimePattern = [regex]::new("[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}")
        $videoFolders = New-Object System.Collections.Generic.List[PSCustomObject]

        foreach ($storage in $storageInfo)
        {
            Get-ChildItem $storage.StoragePath | Where-Object {
                $_.Attributes -like "*Directory*" -and`
                ([regex]::Match($_.Name,$guidPattern)).Value -in $cams.Id -and`
                [datetime]::ParseExact(([regex]::Match($_.Name,$dateTimePattern)).Value,'yyyy-MM-dd_HH-mm-ss',$null) -ge $timeRange.StartDateTime -and`
                [datetime]::ParseExact(([regex]::Match($_.Name,$dateTimePattern)).Value,'yyyy-MM-dd_HH-mm-ss',$null) -le $timeRange.StopDateTime
            } | ForEach-Object {
                $row = [PSCustomObject]@{
                    StorageId = $storage.StorageId
                    Path = $_.FullName
                }
                $videoFolders.Add($row)

                $baseFolder = New-Item -Path "$($NewStoragePath)\$($storage.StorageId)" -ItemType Directory -Force
                Copy-Item -Path "$($storage.StoragePath)\config.xml", "$($storage.StoragePath)\cache.xml", "$($storage.StoragePath)\desktop.ini", "$($storage.StoragePath)\synckey" -Destination $baseFolder.FullName
            }  
        }
    }

    end {
        foreach ($folder in $videoFolders)
        {
            #robocopy /E /COPYALL /DCOPY:DAT $($folder.Path) "$($NewStoragePath)\$($folder.StorageId)" *.*
            $index = ($folder.Path).LastIndexOf('\')+1
            $newFolderName = $folder.Path.Substring($index,$folder.Path.Length - $index)
            Copy-Item -Path $folder.Path -Destination "$($NewStoragePath)\$($folder.StorageId)\$($newFolderName)" -Recurse -Container -Force

        }

        Get-ChildItem -Path $NewStoragePath -Directory -Recurse | ForEach-Object {
            & attrib +S $_.FullName
        }
    }
}

function Show-DateTimeSelector {    
    If ($IsCoreCLR){
        $MorePadding = 25
    }
    else {
        $MorePadding = 0
    }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object Windows.Forms.Form -Property @{
        StartPosition   = [Windows.Forms.FormStartPosition]::CenterScreen
        Size            = [drawing.size]::new(450,325 + $MorePadding)
        Text            = "Set Start and End Date/Time"
        Topmost         = $true
        MinimizeBox     = $false
        MaximizeBox     = $false
    }

    $startLabel = New-Object Windows.Forms.Label -Property @{
        Text = 'Start Date/Time'
        Location = [drawing.size]::new(40,15)
        Size = [drawing.size]::new(125,25)
        TextAlign = 'MiddleCenter'
        Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 10, [System.Drawing.FontStyle]::Bold)
    }
    $form.Controls.Add($startLabel)

    $stopLabel = New-Object Windows.Forms.Label -Property @{
        Text = 'Stop Date/Time'
        Location = [drawing.size]::new(265,15)
        Size = [drawing.size]::new(125,25)
        TextAlign = 'MiddleCenter'
        Font = [System.Drawing.Font]::new("Microsoft Sans Serif", 10, [System.Drawing.FontStyle]::Bold)
    }
    $form.Controls.Add($stopLabel)

    $startDateCalendar = New-Object Windows.Forms.MonthCalendar -Property @{
        Location = [drawing.size]::new(15,45)
        ShowTodayCircle   = $false
        MaxSelectionCount = 1
    }
    $form.Controls.Add($startDateCalendar)

    $stopDateCalendar = New-Object Windows.Forms.MonthCalendar -Property @{
        Location = [drawing.size]::new(240,45)
        ShowTodayCircle   = $false
        MaxSelectionCount = 1
    }
    $form.Controls.Add($stopDateCalendar)

    $startTimePicker = New-Object System.Windows.Forms.DateTimePicker -Property @{
        Size = [Drawing.Size]::new(125,25)
        Location = [Drawing.Size]::new(40,205 + $MorePadding)
        ShowUpDown = $true
        Format = [System.Windows.Forms.DateTimePickerFormat]::Time
    }
    $form.Controls.Add($startTimePicker)

    $stopTimePicker = New-Object System.Windows.Forms.DateTimePicker -Property @{
        Size = [Drawing.Size]::new(125,25)
        Location = [Drawing.Size]::new(265,205 + $MorePadding)
        ShowUpDown = $true
        Format = [System.Windows.Forms.DateTimePickerFormat]::Time
    }
    $form.Controls.Add($stopTimePicker)

    $okButton = New-Object Windows.Forms.Button -Property @{
        Location     = [drawing.size]::new(145,235 + $MorePadding)
        Size         = [drawing.size]::new(75,23)
        Text         = 'OK'
        DialogResult = [Windows.Forms.DialogResult]::OK
    }
    $form.AcceptButton = $okButton
    $form.Controls.Add($okButton)

    $cancelButton = New-Object Windows.Forms.Button -Property @{
        Location     = [drawing.size]::new(220,235 + $MorePadding)
        Size         = New-Object Drawing.Size 75, 23
        Text         = 'Cancel'
        DialogResult = [Windows.Forms.DialogResult]::Cancel
    }
    $form.CancelButton = $cancelButton
    $form.Controls.Add($cancelButton)

    $result = $form.ShowDialog()

    if ($result -eq [Windows.Forms.DialogResult]::OK) {
        $startDate = $startDateCalendar.SelectionStart
        $startTime = $startTimePicker.Value
        $startSelectionDate = ([DateTime]::new($startDate.Year,$startDate.Month,$startDate.Day,$startTime.Hour,$startTime.Minute,0))

        $stopDate = $stopDateCalendar.SelectionStart
        $stopTime = $stopTimePicker.Value
        $stopSelectionDate = ([DateTime]::new($stopDate.Year,$stopDate.Month,$stopDate.Day,$stopTime.Hour,$stopTime.Minute,0))

        if ($startSelectionDate -ge $stopSelectionDate)
        {
            Write-Warning "The 'Start Date/Time' must be earlier than the 'Stop Date/Time'. Please try again."
            Break
        } elseif ($stopSelectionDate -ge (Get-Date)) {
            Write-Warning "The 'Stop Date/Time' must be earlier than the current date/time. Please try again."
            Break
        } else {
            return [PSCustomObject]@{
                StartDateTime   = $startSelectionDate
                StopDateTime     = $stopSelectionDate
            }
        }
    }
}