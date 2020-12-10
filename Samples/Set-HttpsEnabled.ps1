function Set-HttpsEnabled {
    <#
    .SYNOPSIS
        Sets the HTTPSEnabled property for a hardware device to whatever value is valid for that device.

    .DESCRIPTION
        Each device driver publishes its own settings and validation parameters to the Management Server
        and values are case sensitive. Some drivers expect "Yes" and others expect "yes" for the same
        setting. This function demonstrates one way you could abstract this complication away into a
        function which will try to find the valid value name for you. All you have to do is supply the
        Enabled or Disabled switch when calling Set-HttpsEnabled.

    .PARAMETER Hardware
        Specifies the hardware device you will be making the change on. You can get this hardware object
        using Get-Hardware.

    .PARAMETER Enabled
        Specifies that the HTTPSEnabled setting should be enabled. The function will figure out it the
        right value is yes, enabled, true, or on, and whether those values should be capitalized or not.

	.PARAMETER Disabled
        Specifies that the HTTPSEnabled setting should be disabled. The function will figure out it the
        right value is no, disabled, false, or off, and whether those values should be capitalized or not.

	.PARAMETER SettingName
        Specifies the name of the HTTPSEnabled setting. Normally this is HTTPSEnabled, but just in case it
        is something else for another driver, you can specify the setting name here. Technically this means
        you could use this function to modify any "boolean" style setting.

    .EXAMPLE
        Get-Hardware | Set-HttpsEnabled -Enabled

        Sets the HTTPSEnabled value for all hardware devices to whatever the "enabled" value is.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName='Enabled')]
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName='Disabled')]
        [VideoOS.Platform.ConfigurationItems.Hardware]
        $Hardware,
        [Parameter(Mandatory, ParameterSetName='Enabled')]
        [switch]
        $Enabled,
        [Parameter(Mandatory, ParameterSetName='Disabled')]
        [switch]
        $Disabled,
        [Parameter(ParameterSetName='Enabled')]
        [Parameter(ParameterSetName='Disabled')]
        [string]
        $SettingName = 'HTTPSEnabled'
    )

    process {
        $validValues = if ($Enabled) { @('yes', 'true', 'on', 'enabled') } else { @('no', 'false', 'off', 'disabled') }
        $infos = $Hardware | Get-HardwareSetting -Name $SettingName -ValueTypeInfo
        Write-Verbose "Valid values for $SettingName on $($Hardware.Model) are $(($infos | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name) -join ', ')"
        if ($null -eq $infos -or ($infos | Get-Member -MemberType NoteProperty).Count -eq 0) {
            Write-Error "ValueTypeInfo for $SettingName could not be found. Use Get-HardwareSetting to see a list of valid setting names."
            return
        }
        
        $valueName = ($infos | Get-Member -MemberType NoteProperty | Where-Object Name -in $validValues).Name
        if ($null -eq $valueName) {
            Write-Error "$SettingName has a value that is neither yes/no, true/false, or on/off."
            return
        }
        Write-Verbose "Setting $SettingName to $($infos.$valueName) on $($Hardware.Name) ($($Hardware.Id))"
        $Hardware | Set-HardwareSetting -Name $SettingName -Value $infos.$valueName
    }
}