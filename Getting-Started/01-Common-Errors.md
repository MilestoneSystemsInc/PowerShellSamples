# Common Errors

The installation script provided in this project's README.md is designed to protect you from common errors when you install things from PowerShell Gallery for the first time. Following are a collection of these errors so if you run into them, you know what it means and what to do!

## No match was found for the specified search criteria and module name

If you receive this error when installing a PowerShell module, there's a good chance you typed the name correctly.

```powershell
PS C:\> Install-Module MilestonePSTools
WARNING: Unable to resolve package source 'https://www.powershellgallery.com/api/v2'.
PackageManagement\Install-Package : No match was found for the specified search criteria and module name
'MilestonePSTools'. Try Get-PSRepository to see all available registered module repositories.
At C:\Program Files\WindowsPowerShell\Modules\PowerShellGet\1.0.0.1\PSModule.psm1:1809 char:21
+ ...          $null = PackageManagement\Install-Package @PSBoundParameters
+                      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : ObjectNotFound: (Microsoft.Power....InstallPackage:InstallPackage) [Install-Package], Ex
   ception
    + FullyQualifiedErrorId : NoMatchFoundForCriteria,Microsoft.PowerShell.PackageManagement.Cmdlets.InstallPackage
```

The issue is not that the module name was wrong or it couldn't be found on PSGallery. The issue is PowerShell couldn't *connect* to [https://www.powershellgallery.com](https://www.powershellgallery.com) because PSGallery requires an HTTPS connection using at least TLS 1.2, and older versions of PowerShellGet still use an older version of TLS or SSL.

### Solution

To solve this, we need to tell PowerShell which protocol(s) we want to use. One way to do this is to run the rather esoteric line of PowerShell code below. It uses the .NET System.Net.ServicePointManager class and modifies the SecurityProtocol to include TLS 1.2 in addition to whatever protocols are already allowed.

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
```

Here's what it looks like after I run this on a clean Windows 10 Sandbox instance...

```powershell
PS C:\> [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
PS C:\> [Net.ServicePointManager]::SecurityProtocol
Tls11, Tls12
PS C:\>
```

## The command was found in the module, but the module could not be loaded

This is really common on Windows 10 because Microsoft's default execution policy on Windows 10 is "Restricted". This means PowerShell is not allowed to execute *any* \*.ps1 files or \*.psm1 files. When you use `Import-Module` to import MilestonePSTools, or when you use a command within the module like `Connect-ManagementServer` the first thing PowerShell does is run the .PSM1 file inside the module's installation folder. With an execution policy of "Restricted", PowerShell can't do that.

```powershell
PS C:\> Connect-ManagementServer -ShowDialog
Connect-ManagementServer : The 'Connect-ManagementServer' command was found in the module 'MilestonePSTools', but the
module could not be loaded. For more information, run 'Import-Module MilestonePSTools'.
At line:1 char:1
+ Connect-ManagementServer -ShowDialog
+ ~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : ObjectNotFound: (Connect-ManagementServer:String) [], CommandNotFoundException
    + FullyQualifiedErrorId : CouldNotAutoloadMatchingModule
```

PowerShell is usually pretty good at giving you the information you need in the error message. In this case, it recommends you to run `Import-Module MilestonePSTools` to get more information about the problem. Here's what that looks like...

```powershell
PS C:\> Import-Module MilestonePSTools
Import-Module : File C:\Program Files\WindowsPowerShell\Modules\MipSdkRedist\21.1.1\MipSdkRedist.psm1 cannot be loaded
because running scripts is disabled on this system. For more information, see about_Execution_Policies at
https:/go.microsoft.com/fwlink/?LinkID=135170.
At line:1 char:1
+ import-module milestonepstools
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : SecurityError: (:) [Import-Module], PSSecurityException
    + FullyQualifiedErrorId : UnauthorizedAccess,Microsoft.PowerShell.Commands.ImportModuleCommand
```

You can see that the more detailed error more specifically references execution policies.

### Solution

The fix is to [change your execution policy](https:/go.microsoft.com/fwlink/?LinkID=135170). I recommend reading more about execution policies from Microsoft as we can't possibly cover the subject here. Our preference for execution policy is to change it to "RemoteSigned". This means you will be able to run any local PowerShell script, but any script downloaded from an untrusted Internet source will be required to be signed by a code signing certificate you already trust. You can make an untrusted "remote" script "local" and trusted by right-clicking on the file and checking the "unblock" checkbox at the bottom of the General tab. If you don't see that checkbox, then the file is not "blocked" and Windows should let you execute the file so long as your execution policy is at least "RemoteSigned".

Run the `Set-ExecutionPolicy` command as Administrator to modify the policy at the machine level. You can also specify a scope of "CurrentUser" or "Process" so if you have time, I do recommend reading Microsoft's KB on execution policies to get a full understanding of the options and their implications.

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
```

## Untrusted repository

While not an error, when you see this message for the first time it can be confusing. Justifiably, you may wonder whether you should proceed to install something from an untrusted source. The PSGallery repository is the [PowerShell Gallery](https://www.powershellgallery.com) managed by Microsoft. It is a collection of thousands of packages containing PowerShell modules like [MilestonePSTools](https://www.powershellgallery.com/packages/MilestonePSTools). By default, the PSGallery repository included with the built-in PowerShellGet module is not trusted. So you will be asked each time you need to install or update a module from this repository.

```powershell
PS C:\> Install-Module MilestonePSTools

Untrusted repository
You are installing the modules from an untrusted repository. If you trust this repository, change its
InstallationPolicy value by running the Set-PSRepository cmdlet. Are you sure you want to install the modules from
'PSGallery'?
```

### Solution

You can either choose to acknowledge this message each time, or you can set the `InstallationPolicy` for the repository to "Trusted". Here's how to do that...

```powershell
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
```
