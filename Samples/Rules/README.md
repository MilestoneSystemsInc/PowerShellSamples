# Working with Rules

Milestone introduced support for working with rules in version 2020 R1, and that support has expanded in the versions released since then. Initially there were many rule actions that, if present, would prevent the rule from being returned when requesting child items from /RuleFolder. In version 2020 R3 the most common rule actions are supported and the functionality is much more usable.

That said - there are currently no functions/cmdlets built-in to MilestonePSTools for manipulating rules from PowerShell. Part of this is limited time available to spend on extending MilestonePSTools, and another is the challenge of designing simple functions to work with a fairly complex concept and interface.

The scripts in this folder are functional examples of how you can work with rules, and more will be added later as time permits. These functions may make their way into the MilestonePSTools module, or perhaps a submodule will be created like "MilestonePSTools.Rules" since any functions developed for working with rules are effectively just creative arrangements of the Get-ConfigurationItem, Invoke-Item, and Set-ConfigurationItem functions which in turn are wrapping the IConfigurationService WCF proxy. You may have a different opinion on how support for rules in PowerShell should be implemented, and by keeping our opinionated versions out of the MilestonePSTools module namespace, it would be easier for you to do things your way without worrying about function name collisions.

## Get-VmsRule

This function is a really simple wrapper around the existing `Get-ConfigurationItem` function which is itself a wrapper around the IConfigurationService WCF client which interfaces directly with the Configuration API on the Management Server. I added the Vms prefix since there's a good chance `Get-Rule` could collide with any number of other modules (think firewalls, antivirus, etc).

It supports wildcards and looks something like this when imported into your PowerShell session and called against a default set of VMS rules.

```powershell
PS C:\> Get-VmsRule | select DisplayName, ItemType, Path, @{ Name = 'Enabled'; Expression = { $_.EnableProperty.Enabled } }

DisplayName                               ItemType Path                                       Enabled
-----------                               -------- ----                                       -------
Default Start Audio Feed Rule             Rule     Rule[162fdb73-e0dc-4a2d-baa6-54b0d2b16684]    True
Default Record on Motion Rule             Rule     Rule[3307c095-a170-49d3-ab11-1baf8783acb9]    True
Default Record on Bookmark Rule           Rule     Rule[4ce46d3e-c4c7-46b2-a580-fc98cdc24611]    True
Default Goto Preset when PTZ is done Rule Rule     Rule[7aa28f82-f3ff-4398-9781-061299178c7f]   False
Default Start Feed Rule                   Rule     Rule[e34e9353-e6f5-43ff-8e8f-d4a558159b2b]    True
Default Record on Request Rule            Rule     Rule[fa2f8209-8d9b-4580-a6eb-17e58c99a610]    True
Default Start Metadata Feed Rule          Rule     Rule[fe61841f-544e-44d7-b7a8-cd709195162d]    True



PS C:\> 
```

## Remove-VmsRule

This is a slightly more complex function than Get-VmsRule, yet still a relatively simple wrapper around the Get-ConfigurationItem, and Invoke-Method functions which use the Configuration API to modify the VMS configuration. Here's what it would look like to remove the 'Default Start Audio Feed Rule' using wildcards in the rule name. If you wanted to actually perform the removal, you can omit the -WhatIf switch.

```powershell
PS C:\> Remove-VmsRule -Name 'Default*Audio*' -WhatIf
What if: Performing the operation "Remove Rule" on target "Default Start Audio Feed Rule".

PS C:\> 
```
