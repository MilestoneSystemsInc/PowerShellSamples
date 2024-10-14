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
        Remove-VmsViewLayout -ListCustomLayouts

        Returns a list of all custom layouts and which Layout Folder they belong to
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