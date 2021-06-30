function Get-UsersInRoles {
    <#
    .SYNOPSIS
        Returns users/groups, the role they are in, and the type of user.
    .DESCRIPTION
        Returns all users/groups, the role they are in, and the type of user (WindowsUser, WindowsGroup, and BasicUser).  WindowsUser
        and WindowsGroup could be either Windows or Active Directory.  If it is a group, it will only display the group.  It will
        not display the users in the group.
    
    .PARAMETER $RoleName
        Allows you to specify the name of a Role.  If left out, it will return info for all roles.

    .EXAMPLE
        Get-UsersInRoles
        
        Returns all users/groups from all roles
        
    .EXAMPLE
        Get-UsersInRoles -RoleName "Administrators"

        Returns all of the users/groups that are in the Administrators role

    .EXAMPLE
        Get-UsersInRoles | Out-GridView

        Outputs the results to a GridView pop-up.
    
    .EXAMPLE
        Get-UsersInRoles | Export-Csv -Path C:\CsvExports\Users.csv -NoTypeInformation

        Exports the information to a CSV file called Users.csv located at C:\CsvExports.  The CsvExports folder must exist before running the command.
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$RoleName
    )

    process {
        $usersInRoles = New-Object System.Collections.Generic.List[PSCustomObject]
        if ([string]::IsNullOrWhiteSpace($RoleName))
        {
            $roles = Get-Role
        } else
        {
            $roles = Get-Role -Name $RoleName
            if ([string]::IsNullOrWhiteSpace($roles))
            {
                Write-Host "Role name does not exist.  Please try again." -ForegroundColor Yellow
                Break
            }
        }
        
        foreach ($role in $roles)
        {
            $users = $role.UserFolder.Users

            foreach ($user in $users)
            {
                $row = [PSCustomObject]@{
                    'Role' = $role.Name
                    'User' = $user.AccountName
                    'UserType' = $user.IdentityType
                }
                $usersInRoles.Add($row)
            }
        }
        $usersInRoles
    }
}

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>