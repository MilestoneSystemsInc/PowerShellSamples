function Test-DataPresence {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = "Camera")]
        [ValidateNotNullOrEmpty()]
        [VideoOS.Platform.ConfigurationItems.Camera]
        $Camera,
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = "Microphone")]
        [ValidateNotNullOrEmpty()]
        [VideoOS.Platform.ConfigurationItems.Microphone]
        $Microphone,
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = "Speaker")]
        [ValidateNotNullOrEmpty()]
        [VideoOS.Platform.ConfigurationItems.Speaker]
        $Speaker,
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = "Metadata")]
        [ValidateNotNullOrEmpty()]
        [VideoOS.Platform.ConfigurationItems.Metadata]
        $Metadata,
        [Parameter(Mandatory)]
        [DateTime]
        $StartTime,
        [Parameter(Mandatory)]
        [DateTime]
        $EndTime
    )
    
    begin {
        
    }
    
    process {
        switch ($PSCmdlet.ParameterSetName) {
            "Camera" {
                $Camera | Test-VideoPresence -StartTime $StartTime -EndTime $EndTime
            }
            "Microphone" {
                $Microphone | Test-AudioPresence -StartTime $StartTime -EndTime $EndTime
            }
            "Speaker" {
                $Speaker | Test-AudioPresence -StartTime $StartTime -EndTime $EndTime
            }
            "Metadata" {
                $Metadata | Test-MetadataPresence -StartTime $StartTime -EndTime $EndTime
            }
        }
    }
    
    end {
        
    }
}

function Test-VideoPresence {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [VideoOS.Platform.ConfigurationItems.Camera]
        $Source,
        [Parameter(Mandatory)]
        [DateTime]
        $StartTime,
        [Parameter(Mandatory)]
        [DateTime]
        $EndTime
    )
    
    process {
        $data = $Source | Get-Snapshot -Timestamp $StartTime -Behavior GetNearest
        
        if ($null -eq $data) {
            Write-Verbose "Could not retrieve a data from $($Source.Name)"
            return $false
        }

        if ($data.DateTime -ge $StartTime -and $data.DateTime -le $EndTime) {
            Write-Verbose "Data retrieved for $($Source.Name) at $($data.DateTime.ToLocalTime())"
            return $true
        }

        if ($data.IsNextAvailable -and $data.NextDateTime -ge $StartTime -and $data.NextDateTime -le $EndTime) {
            Write-Verbose "Data retrieved for $($Source.Name) from before StartTime, but the next available image is at $($data.NextDateTime.ToLocalTime()) which falls between StartTime and EndTime"
            return $true
        }

        if ($data.DateTime -gt $EndTime) {
            Write-Verbose "The nearest data available to StartTime for $($Source.Name) is $($data.DateTime.ToLocalTime()) which falls outside the desired range of $($StartTime.ToLocalTime()) to $($EndTime.ToLocalTime())"
            return $false
        }

        return $false
    }
}

function Test-AudioPresence {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName="Microphone")]
        [ValidateNotNullOrEmpty()]
        [Alias("Device")]
        [VideoOS.Platform.ConfigurationItems.Microphone]
        $Microphone,
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName="Speaker")]
        [ValidateNotNullOrEmpty()]
        [VideoOS.Platform.ConfigurationItems.Speaker]
        $Speaker,
        [Parameter(Mandatory)]
        [DateTime]
        $StartTime,
        [Parameter(Mandatory)]
        [DateTime]
        $EndTime
    )
    
    process {
        switch ($PSCmdlet.ParameterSetName) {
            "Microphone" {
                $device = $Microphone
                
            }
            "Speaker" {
                $device = $Speaker
            }
        }
        $item = $device | Get-PlatformItem
        if ($null -eq $item) {
            Write-Error "Could not connect to $($device.Name)"
        }
        $source = [VideoOS.Platform.Data.PcmAudioSource]::new($item)
        $source.Init()
        
        $data = $source.GetNearest($StartTime)

        if ($null -eq $data) {
            Write-Verbose "Could not retrieve a data from $($Source.Name)"
            return $false
        }

        if ($data.DateTime -ge $StartTime -and $data.DateTime -le $EndTime) {
            Write-Verbose "Data retrieved for $($Source.Name) at $($data.DateTime.ToLocalTime())"
            return $true
        }

        if ($data.IsNextAvailable -and $data.NextDateTime -ge $StartTime -and $data.NextDateTime -le $EndTime) {
            Write-Verbose "Data retrieved for $($Source.Name) from before StartTime, but the next available image is at $($data.NextDateTime.ToLocalTime()) which falls between StartTime and EndTime"
            return $true
        }

        if ($data.DateTime -gt $EndTime) {
            Write-Verbose "The nearest data available to StartTime for $($Source.Name) is $($data.DateTime.ToLocalTime()) which falls outside the desired range of $($StartTime.ToLocalTime()) to $($EndTime.ToLocalTime())"
            return $false
        }

        return $false
    }
    
    end {
        $source.Close()
    }
}

function Test-MetadataPresence {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [VideoOS.Platform.ConfigurationItems.Metadata]
        $Metadata,
        [Parameter(Mandatory)]
        [DateTime]
        $StartTime,
        [Parameter(Mandatory)]
        [DateTime]
        $EndTime
    )
    
    process {
        try {
            $item = $Metadata | Get-PlatformItem
            if ($null -eq $item) {
                Write-Verbose "Could not connect to $($Metadata.Name)"
                return $false
            }

            $source = [VideoOS.Platform.Data.MetadataPlaybackSource]::new($item)
            $source.Init()
            $data = $source.GetNearest($StartTime)
            if ($null -eq $data) {
                Write-Verbose "Could not retrieve data from $($item.Name)"
                return $false
            }

            if ($data.DateTime -ge $StartTime -and $data.DateTime -le $EndTime) {
                Write-Verbose "Data retrieved for $($item.Name) at $($data.DateTime.ToLocalTime())"
                return $true
            }

            if ($null -ne $data.NextDateTime -and $data.NextDateTime -ge $StartTime -and $data.NextDateTime -le $EndTime) {
                Write-Verbose "Data retrieved for $($item.Name) from before StartTime, but the next available data is at $($data.NextDateTime) UTC which falls between StartTime and EndTime"
                return $true
            }

            if ($data.DateTime -gt $EndTime) {
                Write-Verbose "The nearest data available to StartTime for $($item.Name) is $($data.DateTime.ToLocalTime()) which falls outside the desired range of $($StartTime.ToLocalTime()) to $($EndTime.ToLocalTime())"
                return $false
            }

            return $false
        }
        catch {
            $false
            Write-Error $_
        }
    }

    end {
        $source.Close()
    }
}