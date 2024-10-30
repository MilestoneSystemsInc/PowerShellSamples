function Get-RoleReport {
    <#
    .SYNOPSIS
        Gets a list of all cameras and the permissions associated with the specified role
    .DESCRIPTION
        Device permissions are saved either as "overall security attributes" at the role level, or they
        are associated with each individual device, or a mix of the two. This report helps consolidate
        permissions into a verbose report where each row represents a role and it's effective permissions
        on a specific camera.
    .EXAMPLE
        PS C:\> Get-RoleReport -RoleName 'Guards' | Export-Csv ~\Desktop\Role-Report.csv
        Creates a CSV containing a list of all devices the 'Guards' role has at least 'GENERIC_READ' access to.
    .EXAMPLE
        PS C:\> Get-RoleReport -IncludeNoAccess | Export-Csv ~\Desktop\Role-Report.csv
        Creates a CSV containing a list of all roles and their permissions on all devices. Devices where the role has no access will be included in the report.
    .NOTES
        This report is not meaningful for the Administrator role, so if your RoleName filter returns only the built-in Administrators role, you will receive an error.
    #>
    [CmdletBinding()]
    param(
        # Specifies the name of the role. Supports wildcard characters. Default is * and returns all roles.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $RoleName = '*',

        # Specifies that rows where the role lacks read access should still be included in the report.
        [Parameter()]
        [switch]
        $IncludeNoAccess
    )

    process {
        $roles = Get-VmsRole -Name $RoleName -ErrorAction Stop | Where-Object RoleType -eq UserDefined
        $cameras = Get-VmsCamera
        if ($null -eq $roles -or $roles.Count -eq 0) {
            Write-Error "Cannot find user-defined role '$RoleName' because it does not exist."
        }

        $overallSecurity = @{}
        foreach($role in $roles) {
            $securityAttributes = @{}
            $invokeInfo = $role.ChangeOverallSecurityPermissions('623d03f8-c5d5-46bc-a2f4-4c03562d4f85')
            foreach ($key in $invokeInfo.GetPropertyKeys()) {
                $securityAttributes.$key = $invokeInfo.GetProperty($key)
            }
            $overallSecurity.($role.Id) = $securityAttributes
        }

        $rowsCompleted = 0
        $totalRows = $cameras.Count * $roles.Count
        try {
            foreach ($camera in $cameras) {
                foreach ($role in $roles) {
                    Write-Progress -Activity "Auding camera permissions per role" -PercentComplete ([int]($rowsCompleted / $totalRows * 100))
                    $acl = $camera | Get-DeviceAcl -Role $role
                    if ($IncludeNoAccess -or $overallSecurity.($role.Id).'GENERIC_READ' -eq 'Allow' -or $acl.SecurityAttributes.GENERIC_READ -eq 'True') {
                        $row = [ordered]@{
                            Role = $role.Name
                            Camera = $camera.Name
                        }
                        foreach ($key in $acl.SecurityAttributes.Keys) {
                            $overallSecurityAttribute = $overallSecurity.($role.Id).$key
                            if ($overallSecurityAttribute -eq 'None') {
                                $row.$key = $acl.SecurityAttributes.$key
                            }
                            else {
                                $row.$key = $overallSecurityAttribute -eq 'Allow'
                            }                            
                        }
                        $row.RoleId = $role.Id
                        $row.CameraId = $camera.Id
        
                        Write-Output ([pscustomobject]$row)
                    }
                    $rowsCompleted++
                }
            }
        }
        finally {
            Write-Progress -Activity "Auding camera permissions per role" -Completed
        }
    }
}