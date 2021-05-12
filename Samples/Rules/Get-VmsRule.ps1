function Get-VmsRule {
    <#
    .SYNOPSIS
        Gets all VMS Rules available through Milestone's Configuration API.
    .DESCRIPTION
        Version 2020 R1 introduced support for rules in the Configuration API. This function is an example of how the Configuration API
        function Get-ConfigurationItem can be used to retrieve all the rules from the /RuleFolder configuration api path.
    .EXAMPLE
        PS C:\> Get-VmsRule -Name Default* | Select DisplayName, Path
        Gets all default rules from the VMS and displays only the name and path of the rule objects
    .EXAMPLE
        PS C:\> Get-VmsRule -Name 'Test Rule #1' | Select DisplayName, Path
        Gets a single rule named 'Test Rule #1' or emits an error if this rule does not exist since no wildcard is present in the Name parameter.
    .PARAMETER Name
        Specifies the display name, or partial name of the rule(s). Wildcards are supported and the default is to return all rules.
    .NOTES
        Support for rules was introduced in version 2020 R1, and early support for rules is quite limited. Check the MIP SDK Configuration API documentation for more information about rules.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('DisplayName')]
        [string]
        $Name = '*'
    )

    begin {
        $ms = Get-ManagementServer -ErrorAction Ignore
        if ($null -eq $ms) {
            throw "You must be connected to a Management Server. Use Connect-ManagementServer and then try again."
        }
        if ([version]$ms.Version -lt [version]'20.1') {
            throw "Support for rules in Milestone's Configuration API was not added until version 2020 R1. You must upgrade the Management Server to use this function."
        }
    }

    process {
        $matchingRuleCount = 0
        Get-ConfigurationItem -Path /RuleFolder -ChildItems | Where-Object DisplayName -like $Name | Foreach-Object {
            $matchingRuleCount++
            Write-Output $_
        }
        
        if ($matchingRuleCount -lt 1 -and ![wildcardpattern]::ContainsWildcardCharacters($Name)) {
            Write-Error "Rule not found matching name '$Name'"
        }        
    }
}