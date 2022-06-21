function Remove-VmsRule {
    <#
    .SYNOPSIS
        Removes all VMS Rules with DisplayName's matching the provided name
    .DESCRIPTION
        Version 2020 R1 introduced support for rules in the Configuration API. This function is an example of how the Configuration API
        functions can be used to retrieve all the rules from the /RuleFolder configuration api path, and remove the matching rules by
        using Invoke-Method to call a Configuration API method available on the /RuleFolder object.

        This advanced function supports "ShouldProcess" so you may use the -WhatIf parameter to see what would happen if the -WhatIf switch
        were omitted.
    .EXAMPLE
        PS C:\> Remove-VmsRule -Name 'Test Rule #1' -WhatIf
        Shows what would happen if you used the same command without the -WhatIf switch
    .EXAMPLE
        PS C:\> Remove-VmsRule -Name 'Test Rule #1'
        Removes the 'Test Rule #1' rule from the Milestone VMS or emits an error if the rule could not be found.
    .PARAMETER Name
        Specifies the display name, or partial name of the rule(s). Wildcards are supported and the default is to return all rules.
    .NOTES
        Support for rules was introduced in version 2020 R1, and early support for rules is quite limited. Check the MIP SDK Configuration API documentation for more information about rules.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('DisplayName')]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name
    )

    begin {
        $ms = Get-VmsManagementServer -ErrorAction Ignore
        if ($null -eq $ms) {
            throw "You must be connected to a Management Server. Use Connect-ManagementServer and then try again."
        }
        if ([version]$ms.Version -lt [version]'20.1') {
            throw "Support for rules in Milestone's Configuration API was not added until version 2020 R1. You must upgrade the Management Server to use this function."
        }
    }

    process {
        $ruleFolder = Get-ConfigurationItem -Path /RuleFolder -Recurse
        $rules = [array]($ruleFolder.Children | Where-Object DisplayName -like $Name)
        if ($rules.Count -lt 1 -and ![wildcardpattern]::ContainsWildcardCharacters($Name)) {
            Write-Error "Rule not found matching name '$Name'"
            return
        }
        foreach ($rule in $rules) {
            if ($PSCmdlet.ShouldProcess($rule.DisplayName, 'Remove Rule')) {
                $invokeInfo = $ruleFolder | Invoke-Method -MethodId RemoveRule
                $invokeInfo | Set-ConfigurationItemProperty -Key 'RemoveRulePath' -Value $rule.Path
                $invokeInfo | Invoke-Method -MethodId RemoveRule
            }
        }
    }
}