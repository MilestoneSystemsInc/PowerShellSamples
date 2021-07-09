# Manual Installation

If your Milestone VMS is "air-gapped" or for any other reason you're unable to install a PowerShell module using the `Install-Module` cmdlet which downloads it directly from PowerShell Gallery, you can still install MilestonePSTools! Follow along to learn how.

## Download the Nupkg files

What on earth is a nupkg file? For starters, you can pronounce it as "Nup-keg" which is fun! And it stands for "NuGet Package". Oh, and NuGet is the name of Microsoft's package manager introduced primarily for managing .NET application packages. In this case, "package" means one or more DLL files and some basic instructions for where they go. Back before ~2010, most .NET developers were manually copying around DLL files and adding references to them when needed. It made it very complicated to share reusable libraries. Now, with NuGet.org, you can reference a package by name, and automatically download/unpack/use that package.

To manually download MilestonePSTools, you'll need to download two files. The first is the MilestonePSTools "raw nupgk file", and the second is the MipSdkRedist nupkg. The MipSdkRedist module is the container used for the Milestone MIP SDK on which MilestonePSTools is based. Here are the links to the two PowerShell modules on PSGallery. Once there, click **Manual Download** under **Installation Options** and then click **Download the raw nupkg file**.

- [MilestonePSTools](https://www.powershellgallery.com/packages/MilestonePSTools)
- [MipSdkRedist](https://www.powershellgallery.com/packages/MipSdkRedist)

These nupkg files are actually ZIP files! If you add the `.zip` extension to the file, you can view/extract the contents like any other zip file. Here's what the contents look like for MilestonePSTools...

![MilestonePSTools nupkg file contents screenshot](https://github.com/MilestoneSystemsInc/PowerShellSamples/blob/main/Getting-Started/images/MilestonePSTools-nupkg-contents.png?raw=true)

Before you extract the ZIP files, make sure to right-click on both files and open **Properties**. If you see a checkbox to "unblock" the files, you should do this before extracting them. Otherwise each individual extracted file will *also* be blocked.

When you extract the files for the module, the best place to put them is in one of the locations PowerShell *automatically* looks for PowerShell modules. If you install the module for *just you*, then you should place the module in your Documents directory under `~\Documents\WindowsPowerShell\Modules`. The folder(s) may not already exist. If so, it is okay to create them yourself.

Alternatively if you want to make the module(s) available to any user on the local machine (useful if you want a service account, local system, or network service to access them from a scheduled task!), you can place them in `C:\Program Files\WindowsPowerShell\Modules`.

The structure for the Modules folder is that the first level includes a folder matching the name of the module, and the subfolder contains one or more versions of that module where the name of the folder matches the exact version of the module as defined in the `*.psd1` file at the root of the specific module's folder. In the example below, we have MilestonePSTools version 21.1.451603, and inside that folder are the contents from the screenshot above such that MilestonePSTools.psd1 exists inside the folder named "21.1.451603".

```text
+---Modules
    +---MilestonePSTools
    |   \---21.1.451603
    +---MipSdkRedist
    |   \---21.1.1
```

Once you have the modules extracted and placed in the right location, you should be able to run `Import-Module MilestonePSTools` and both MipSdkRedist and MilestonePSTools will be loaded into your PowerShell session. If you get an error message, check out [01-CommonErrors](01-CommonErrors.md) to see if we've already shared some tips on how to deal with it!
