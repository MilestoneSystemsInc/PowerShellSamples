function Get-DevicePermissionsByRole {
    <#
    .SYNOPSIS
        Get device permissions for specified role(s)
    .DESCRIPTION
        Gets Live/Listen, Playback, and Export permissions for specified device types in specified Roles. Only Cameras, Microphones, Speakers,
        and Metadata support these permissions. If a Role does not have Read permissions to a device, then the output will indicate it doesn't have
        Live/Listen, Playback, or Export permissions since you can't do any of those if you cannot read/see the device.

        This script can be relatively easily expanded to include other permissions as well. The comments in the code should help with that.
    .EXAMPLE
        $role = Get-VmsRole -Name Operators
        Get-DevicePermissionsByRole -Role $role | Out-GridView

        Gets device permissions for the "Operators" role. Since no Device Type is specified, it will retrieve the permissions for cameras. The output
        will be sent to the built-in Grid View in PowerShell
    .EXAMPLE
        $role = Get-VmsRole -Name Guards
        Get-DevicePermissionsByRole -Role $role -DeviceType Camera, Metadata | Export-Csv C:\tmp\DevicePermissions.csv -NoTypeInformation

        Gets Camera and Metadata permissions for the "Guards" role and exports it to a CSV called DevicePermissions.csv located in C:\tmp
    .EXAMPLE
        $role = Get-VmsRole -RoleType UserDefined
        Get-DevicePermissionsByRole -Role $role

        The first line gets all Roles in the system except the built-in Administrators role. The second line gets Camera permissions for each role
        and just outputs it to the console.
    #>
    
    
    [CmdletBinding()]
    param(
        # Specifies which role(s) to be included in the report. Omit this value and all user-defined roles will be included.
        [Parameter()]
        [VideoOS.Platform.ConfigurationItems.Role[]]
        $Role,

        # Specifies which device type(s) to be included in the report.
        [Parameter()]
        [ValidateSet('All', 'Camera', 'Microphone', 'Speaker', 'Metadata')]
        [string[]]
        $DeviceType = 'Camera'
    )

    begin {
        function Get-Permissions {
            param(
                [Parameter()]
                [string]
                $Type,
                [Parameter()]
                [MilestoneLib.DeviceAcl]
                $Acl,
                [Parameter()]
                [hashtable]
                $NamespaceSettings
            )

            switch ($Type)
            {
                # The camera label values are pulled from running this (change Role_Name to the name of a non-Administrator role)
                # Get-VmsRoleOverallSecurity -Role Role_Name -SecurityNamespace '623d03f8-c5d5-46bc-a2f4-4c03562d4f85'
                Camera {$liveLabel = "VIEW_LIVE";$playbackLabel = "PLAYBACK";$exportLabel = "EXPORT"}

                # The microphone label values are pulled from running this (change Role_Name to the name of a non-Administrator role)
                # Get-VmsRoleOverallSecurity -Role Role_Name -SecurityNamespace '15f48f88-ca89-4926-9a84-2b02864ec77a'
                Microphone {$liveLabel = "LISTEN";$playbackLabel = "PLAYBACK";$exportLabel = "EXPORT"}

                # The speaker label values are pulled from running this (change Role_Name to the name of a non-Administrator role)
                # Get-VmsRoleOverallSecurity -Role Role_Name -SecurityNamespace '48b602bc-e752-4bbf-8e2a-7de01f53a6dd'
                Speaker {$liveLabel = "LISTEN";$playbackLabel = "PLAYBACK";$exportLabel = "EXPORT"}

                # The metadata label values are pulled from running this (change Role_Name to the name of a non-Administrator role)
                # Get-VmsRoleOverallSecurity -Role Role_Name -SecurityNamespace 'ede4d51c-f691-4894-9c0b-c3ae096dc04d'
                Metadata {$liveLabel = "LIVE";$playbackLabel = "PLAYBACK";$exportLabel = "EXPORT"}
            }

            foreach ($label in 'live','playback','export')
            {
                # $namespaceSettings values can be 'Allow', 'Deny', or 'None'. These are settings in Overall Security tab in Roles.
                # $acl.SecurityAttributes settings can be 'True' or 'False'. These are settings on Device tab in Roles.
                
                # If Read in Overall Security is set to Deny for a device type, then nothing else needs to be checked.
                if ($namespaceSettings.GENERIC_READ -eq 'Deny') {
                    $livePermission = $false
                    $playbackPermission = $false
                    $exportPermission = $false
                } else {
                    $permissionLabel = (Get-Variable -Name "$($label)Label").Value

                    # There are many different combinations between the settings in Overall Security and the device specific settings.
                    # We need to check all of the combinations.
                    if ($namespaceSettings.$permissionLabel -eq 'Deny') {
                        New-Variable -Name "$($label)Permission" -Value $false
                    } elseif ($namespaceSettings.GENERIC_READ -eq 'Allow' -and $namespaceSettings.$permissionLabel -eq 'Allow') {
                        New-Variable -Name "$($label)Permission" -Value $true
                    } elseif ($acl.SecurityAttributes.GENERIC_READ -eq 'True' -and $namespaceSettings.$permissionLabel -eq 'Allow') {
                        New-Variable -Name "$($label)Permission" -Value $true
                    } elseif ($namespaceSettings.GENERIC_READ -eq 'Allow' -and $acl.SecurityAttributes.$permissionLabel -eq 'True') {
                        New-Variable -Name "$($label)Permission" -Value $true
                    } elseif ($acl.SecurityAttributes.GENERIC_READ -eq 'True' -and $acl.SecurityAttributes.$permissionLabel -eq 'True') {
                        New-Variable -Name "$($label)Permission" -Value $true
                    } elseif ($acl.SecurityAttributes.GENERIC_READ -eq 'False' -or $acl.SecurityAttributes.$permissionLabel -eq 'False') {
                        New-Variable -Name "$($label)Permission" -Value $false
                    } else { 
                        New-Variable -Name "$($label)Permission" -Value $false
                    }
                }
            }
            # Return the results as a hashtable
            return @{"live" = $livePermission;"playback" = $playbackPermission;"export" = $exportPermission}
        }
    }

    process {
        $buildRow = {
            param($currentRole, $recorder, $hardware, $device, $overallSecurity, $securityNamespace)
            $livePermission = $playbackPermission = $exportPermission = $false
            $acl = $null
            $namespaceSettings = $overallSecurity | Where-Object { $_.SecurityNamespace -eq $securityNamespace }
            $acl = $device | Get-DeviceAcl -Role $currentRole
            $type = $device.Path -replace '(\w+)\[.+\](?:/.+)?', '$1'

            if ($namespaceSettings.GENERIC_READ -eq 'Deny') {
                $livePermission = $false
                $playbackPermission = $false
                $exportPermission = $false
            } else {
                # The results of the function are returned as a hashtable and assigned to the $permissions variable
                $permissions = Get-Permissions -Type $type -Acl $acl -NamespaceSettings $namespaceSettings

                $livePermission = $permissions["live"]
                $playbackPermission = $permissions["playback"]
                $exportPermission = $permissions["export"]                
            }

            [pscustomobject]@{
                Role                = $currentRole.Name
                Recorder            = $recorder.Name
                Hardware            = $hardware.Name
                Device              = $device.Name
                DeviceType          = $type
                LivePermission      = $livePermission
                PlaybackPermission  = $playbackPermission
                ExportPermission    = $exportPermission
            }
        }
        if ($Role.Count -eq 0) {
            $Role = Get-VmsRole -RoleType UserDefined
        }

        if ('All' -in $DeviceType) {
            $DeviceType = 'Camera', 'Microphone', 'Speaker', 'Metadata'
        }

        $roleNum = 0
        $recordingServers = Get-VmsRecordingServer
        foreach ($currentRole in $Role) {
            Write-Progress -Activity "Collecting permissions info for '$($currentRole.Name)' role" -Id 1 -PercentComplete ($roleNum / $Role.Count * 100)
            if ($currentRole.RoleType -ne 'UserDefined') {
                Write-Warning "Skipping $($currentRole.Name) as this role has full access to all VMS configuration and data."
                continue
            }
            $overallSecurity = $currentRole | Get-VmsRoleOverallSecurity -ErrorAction SilentlyContinue
            
            $recNum = 0
            foreach ($rec in $recordingServers) {
                Write-Progress -Activity "Getting device permissions for '$($rec.Name)' recording server" -ParentId 1 -Id 2 -PercentComplete ($recNum / $recordingServers.Count * 100)
                foreach ($hw in $rec | Get-VmsHardware | Where-Object Enabled) {
                    if ('Camera' -in $DeviceType) {
                        foreach ($dev in $hw | Get-VmsCamera -EnableFilter Enabled) {
                            $buildRow.Invoke($currentRole, $rec, $hw, $dev, $overallSecurity, '623d03f8-c5d5-46bc-a2f4-4c03562d4f85')
                        }
                    }
                    if ('Microphone' -in $DeviceType) {
                        foreach ($dev in $hw | Get-Microphone | Where-Object Enabled) {
                            $buildRow.Invoke($currentRole, $rec, $hw, $dev, $overallSecurity, '15f48f88-ca89-4926-9a84-2b02864ec77a')
                        }
                    }
                    if ('Speaker' -in $DeviceType) {
                        foreach ($dev in $hw | Get-Speaker | Where-Object Enabled) {
                            $buildRow.Invoke($currentRole, $rec, $hw, $dev, $overallSecurity, '48b602bc-e752-4bbf-8e2a-7de01f53a6dd')
                        }
                    }
                    if ('Metadata' -in $DeviceType) {
                        foreach ($dev in $hw | Get-Metadata | Where-Object Enabled) {
                            $buildRow.Invoke($currentRole, $rec, $hw, $dev, $overallSecurity, 'ede4d51c-f691-4894-9c0b-c3ae096dc04d')
                        }
                    }
                }
                $recNum++
            }
            Write-Progress -Activity "Getting device permissions for '$($rec.Name)' recording server" -ParentId 1 -Id 2 -PercentComplete 100 -Completed
            $roleNum++
        }
        Write-Progress -Activity "Collecting permissions info for '$($currentRole.Name)' role" -Id 1 -PercentComplete 100 -Completed
    }
}