function Get-UsersInRoles {
    <#
    .SYNOPSIS
        Returns users/groups, the role they are in, and the type of user.
    .DESCRIPTION
        Returns all users/groups, the role they are in, and the type of user (WindowsUser, WindowsGroup, and BasicUser).  WindowsUser
        and WindowsGroup could be either Windows or Active Directory.  If it is a group, it will only display the group.  It will
        not display the users in the group.
    .EXAMPLE
        PS C:\> Get-UsersInRoles
        Returns all users/groups from all roles
    .EXAMPLE
        PS C:\> Get-UsersInRoles -RoleName "Administrators"
        Returns all of the users/groups that are in the Administrators role
    .EXAMPLE
        PS C:\> Get-UsersInRoles | Out-GridView
        Outputs the results to a GridView pop-up.
    .EXAMPLE
        PS C:\> Get-UsersInRoles | Export-Csv -Path C:\CsvExports\Users.csv -NoTypeInformation
        Exports the information to a CSV file called Users.csv located at C:\CsvExports.  The CsvExports folder must exist before running the command.
    #>
    [CmdletBinding()]
    param (
        # Specifies the name of the role. Supports wildcard characters. Default is * and returns all roles.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $RoleName = '*'
    )

    process {
        [bool]$resultFound
        foreach ($role in Get-Role -Name $RoleName)
        {
            $resultFound = $true
            foreach ($user in $role.UserFolder.Users)
            {
                [pscustomobject]@{
                    Role = $role.Name
                    User = $user.AccountName
                    Domain = $user.Domain
                    IdentityType = $user.IdentityType
                }
            }
        }
        if (-not $resultFound -and -not [system.management.automation.wildcardpattern]::ContainsWildcardCharacters($RoleName)) {
            Write-Error "Cannot find role '$RoleName' because it does not exist."
        }
    }
}