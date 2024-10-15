function Remove-VmsViewLayout {
    <#
    .SYNOPSIS
        Removes a view layout, that has previously been added, from the Milestone XProtect system
    .DESCRIPTION
        Removes a custom view layout that was added via Add-VmsViewLayout or some other method. The view layout name and the
        layout group need to be provided.
    .PARAMETER ViewLayoutName
        Specify the name of the view to be removed.
    .PARAMETER LayoutFolder
        Specify which view layout group the view to be removed resides in.
    .PARAMETER ListCustomLayouts
        List all custom layouts along with the Layout Folder they belong to.
    .EXAMPLE
        Remove-VmsViewLayout -ViewLayoutName 'Sample View' -LayoutFolder '16:9'

        Removes custom view layout named 'Sample View'
    .EXAMPLE
        # Connect-Vms only required if not already connected
        Connect-Vms -ShowDialog -AcceptEula
        Remove-VmsViewLayout -ListCustomLayouts

        Returns a list of all custom layouts and which Layout Folder they belong to
    .NOTES
        The software provided by Milestone Systems, Inc. (hereinafter referred to as "the Software") is provided on
        an "as is" basis, without any warranties or representations, express or implied, including but not limited to
        the implied warranties of merchantability, fitness for a particular purpose, or non-infringement.
        
        Warranty Disclaimer:
        The Software is provided without any warranty of any kind, whether expressed or implied. Milestone Systems, Inc.
        expressly disclaims all warranties, conditions, and representations, including but not limited to warranties of
        title, non-infringement, merchantability, or fitness for a particular purpose. The entire risk arising out of the
        use or performance of the Software remains with the user.
    
        Support Disclaimer:
        Milestone Systems, Inc. does not provide any support or maintenance services for the Software. The user acknowledges
        and agrees that Milestone Systems, Inc. shall have no obligation to provide any updates, bug fixes, or technical
        support for the Software, whether through telephone, email, or any other means.
    
        User Responsibility:
        The user acknowledges and agrees that they are solely responsible for the selection, installation, use, and results
        obtained from the Software. Milestone Systems, Inc. shall not be held liable for any errors, defects, or damages arising
        from the use or inability to use the Software, including but not limited to direct, indirect, incidental, consequential,
        or special damages.
    
        Indemnification:
        The user agrees to indemnify, defend, and hold harmless Milestone Systems, Inc. and its directors, officers, employees,
        and agents from any and all claims, liabilities, damages, losses, costs, and expenses (including reasonable attorneys' fees)
        arising out of or related to the user's use or misuse of the Software.

        By using the Software, the user acknowledges that they have read and understood this clause and agree to be bound by its terms.
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Remove')]
        [string]
        $ViewLayoutName,
        [Parameter(Mandatory, ParameterSetName = 'Remove')]
        [ValidateSet('4:3','16:9','4:3 Portrait','16:9 Portrait')]
        [string]
        $LayoutFolder,
        [Parameter(Mandatory, ParameterSetName = 'List')]
        [switch]
        $ListCustomLayouts
    )

    $ms = Get-VmsManagementServer -ErrorAction SilentlyContinue
    if ([string]::IsNullOrEmpty($ms.Version)) {
        Write-Warning "Please connect to a Milestone XProtect system first."
        break
    }

    $layoutGroups = $ms.LayoutGroupFolder.LayoutGroups    
    $customViews = New-Object System.Collections.Generic.List[PSCustomObject]
    if ($ListCustomLayouts) {
        foreach ($lg in $layoutGroups) {
            $task = $lg.LayoutFolder.RemoveLayout()
            ($task.ItemSelectionValues).Keys | ForEach-Object {
                $viewName = $_
                $row = [PSCustomObject]@{
                    "View Layout Name" = $viewName
                    "View Layout Folder" = $lg.Name
                }
                $customViews.Add($row)
            }
        }
        
        if (-not [string]::IsNullOrEmpty($customViews.'View Layout Folder')) {
            return $customViews
            break
        } else {
            Write-Warning "There are no custom view layouts in this system."
            break
        }
    }

    $layoutGroup = $layoutGroups | Where-Object {$_.Name -eq $LayoutFolder}
    $layout = $layoutGroup.LayoutFolder.Layouts | Where-Object {$_.Name -eq $ViewLayoutName}
    if ([string]::IsNullOrEmpty($layout.Id)) {
        Write-Warning 'The selected view does not exist in the selected view layout group.'
        break
    }
    
    $null = $layoutGroup.LayoutFolder.RemoveLayout($layout.Path)
}