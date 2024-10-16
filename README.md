[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]


<!-- PROJECT LOGO -->
<br />
<p align="center">
  <a href="https://github.com/MilestoneSystemsInc/PowerShellSamples">
    <img src="images/logo.png" alt="Logo" width="128" height="128">
  </a>

  <h3 align="center">Manage Milestone with PowerShell</h3>

  <p align="center">
    A collection of sample scripts to bootstrap your Milestone XProtect VMS Management Adventure
    <br />
    <a href="https://github.com/MilestoneSystemsInc/PowerShellSamples"><strong>Explore the samples »</strong></a>
    <br />
    <br />
    <a href="https://github.com/MilestoneSystemsInc/PowerShellSamples/issues">Report Bug</a>
    ·
    <a href="https://github.com/MilestoneSystemsInc/PowerShellSamples/issues">Request Feature</a>
  </p>
</p>



<!-- TABLE OF CONTENTS -->
## Table of Contents

* [About the Project](#about-the-project)
* [Getting Started](#getting-started)
  * [Prerequisites](#prerequisites)
  * [Installation](#installation)
* [Usage](#usage)
* [Roadmap](#roadmap)
* [Contributing](#contributing)
* [License](#license)
* [Contact](#contact)
* [Acknowledgements](#acknowledgements)



<!-- ABOUT THE PROJECT -->
## About The Project

This repository contains sample PowerShell scripts for managing and automating tasks related to Milestone XProtect VMS software using MilestonePSTools. It is intended to be a supplement to the built-in documentation available in many cmdlets within MilestonePSTools which you can access using `Get-Help`.

[![Product Name Screen Shot][product-screenshot]]()

<!-- GETTING STARTED -->
## Getting Started

In order to make the most out of MilestonePSTools you will need at least some basic familiarity with PowerShell or other shells. It's possible to perform very basic actions in a few lines of PowerShell with limited experience. With a bit more experience and ambition, it's also possible to develop extensive and powerfull tools or entire modules to automate important business and maintenance tasks unique to your organization.

[![IMAGE ALT TEXT](http://img.youtube.com/vi/qZ-I-Imm7tk/0.jpg)](http://www.youtube.com/watch?v=qZ-I-Imm7tk "MilestonePSTools Demo")

If you're new to PowerShell, there are a wide range of resources available to learn. One popular example is the [Learn Windows PowerShell in a Month of Lunches](https://www.youtube.com/playlist?list=PL6D474E721138865A) series which, while last updated in 2014, is still a good resource for picking up the syntax and style.

### Prerequisites

MilestonePSTools is developed using the latest build of Milestone's MIP SDK. As such, it has the following prerequisits:
* Milestone XProtect VMS (XProtect Essential+, Express+, Professional+, Expert, or Corporate) 2014 or newer
* Windows Desktop/Server edition (not compatible with PowerShell Core)
* .NET Framework 4.7
* PowerShell 5.1. Use `$PSVersionTable` to determine the PSVersion of your current PowerShell terminal. If you need to upgrade PowerShell, download Windows [Management Framework 5.1](https://www.microsoft.com/en-us/download/details.aspx?id=54616) from Microsoft.

### Installation

You can install MilestonePSTools on the computer where your Milestone VMS is installed, but that is not required. In fact, from a security standpoint it is best to avoid installing software on the same server as your VMS if it's not necessary. Just as the XProtect Smart Client and Management Client may be used from a networked PC, so too can MilestonePSTools be used from a remote system.

You can copy & paste the script below into a PowerShell prompt, or PowerShell ISE, and as long as you have PowerShell 5.1 installed, it should get you up and running.

```powershell
$script = @"
Write-Host 'Setting SecurityProtocol to TLS 1.2, Execution Policy to RemoteSigned' -ForegroundColor Green
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Confirm:`$false -Force

Write-Host 'Registering the NuGet package source if necessary' -ForegroundColor Green
if (`$null -eq (Get-PackageSource -Name NuGet -ErrorAction Ignore)) {
    `$null = Register-PackageSource -Name NuGet -Location https://www.nuget.org/api/v2 -ProviderName NuGet -Trusted -Force
}

Write-Host 'Installing the NuGet package provider' -ForegroundColor Green
`$nugetProvider = Get-PackageProvider -Name NuGet -ErrorAction Ignore
`$requiredVersion = [Microsoft.PackageManagement.Internal.Utility.Versions.FourPartVersion]::Parse('2.8.5.201')
if (`$null -eq `$nugetProvider -or `$nugetProvider.Version -lt `$requiredVersion) {
    `$null = Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
}

Write-Host 'Setting PSGallery as a trusted repository' -ForegroundColor Green
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

Write-Host 'Installing PowerShellGet 2.2.5 or greater if necessary' -ForegroundColor Green
if (`$null -eq (Get-Module -ListAvailable PowerShellGet | Where-Object Version -ge 2.2.5)) {
    `$null = Install-Module PowerShellGet -MinimumVersion 2.2.5 -Force
}

Write-Host 'Installing or updating MilestonePSTools' -ForegroundColor Green
if (`$null -eq (Get-Module -ListAvailable MilestonePSTools)) {
    Install-Module MilestonePSTools
}
else {
    Update-Module MilestonePSTools
}
"@
Start-Process -FilePath powershell.exe -ArgumentList "-Command $script" -Verb RunAs
```

### Holy moly that's a lot of PowerShell

The script above may look intimidating, and you should _never_ copy and paste code of any kind if you don't know what it does. In short, the script is designed to make it as easy and fast as possible to get MilestonePSTools installed. Sometimes your PowerShell environment needs a few adjustments and updates to be able to install PowerShell modules. Let's break down what this actually does, just in case your boss asks!

1. A script is launched in a new PowerShell instance requiring elevation
2. Sets the HTTPS security protocol to TLS 1.2 which is required for communicating with [PSGallery](https://powershellgallery.com)
3. Sets the execution policy to `RemoteSigned`. The default on Windows 10 is `Restricted` and that will prevent you from actually using any PowerShell modules. `RemoteSigned` means any scripts that are "blocked" must be signed.
4. Registers [NuGet.org](https://www.nuget.org) as a package source. This is not strictly necessary, but can be useful if you need to install .NET packages from PowerShell, and in the future we may update MilestonePSTools to depend on the official [MIP SDK NuGet packages](https://www.nuget.org/profiles/milestonesys).
5. Installs the NuGet package provider which is used by PowerShellGet as a source for installing PowerShell modules. You may have an older version of PowerShellGet so this will ensure it gets updated.
6. Sets the PSGallery repository as a trusted source for PowerShell modules. This is not mandatory but will prevent you from having to acknowledge each module you install.
7. Updates to the latest PowerShellGet module
8. Installs/updates MilestonePSTools to `C:\Program Files\WindowsPowerShell\Modules\`


<!-- USAGE EXAMPLES -->
## Usage
### Get connected
* If a Milestone connection profile named "default" already exists, a connection will be established to the
management server address in that connection profile. If no such profile exists, a Milestone login dialog will be
displayed. The "-AcceptEula" parameter is only required the first time the command is used by the current Windows
user. If the command is used later under a different Windows user account, the "-AcceptEula" parameter will be
required one time for that user.
    ```powershell
    Connect-Vms -AcceptEula
    ```
* If a Milestone connection profile named "MyVMS" already exists, a connection will be established to the management
server address in that connection profile. If no such profile exists, a Milestone login dialog will be displayed.
Upon successful logon, the named profile will be saved to disk, and calling 'Connect-Vms -Name MyVMS' in the
future will automatically connect to the same server address with the same credentials.
    ```powershell
    Connect-Vms -Name 'MyVMS'
    ```
* Prompt for a Windows or Active Directory credential, and then establish a connection to http://MyVMS. Upon
successful connection, a connection profile named "MyVMS" will be added or updated.
    ```powershell
    Connect-Vms -Name 'MyVMS' -ServerAddress 'http://MyVMS' -Credential (Get-Credential)
    ```
* Show a Milestone login dialog, and on successful connection, add or update the connection profile named "MyVMS".
    ```powershell
    Connect-Vms -Name 'MyVMS' -ShowDialog
    ```
* Prompt for a Basic User credential, and then establish a connection to http://MyVMS.
    ```powershell
    Connect-Vms -ServerAddress 'http://MyVMS' -Credential (Get-Credential) -BasicUser
    ```

### List all enabled cameras
```powershell
# Slower but uses Configuration API so each object can be used to modify configuration
Get-VmsCamera | Select Name

# Faster but provides limited access to camera properties and Items cannot be used to
# modify configuration
Get-PlatformItem -Kind (Get-Kind -List | ? DisplayName -eq Camera).Kind | Select Name
```

### Add hardware
* Using Add-Hardware
    ```powershell
    # Select a Recording Server by name
    $recorder = Get-VmsRecordingServer -Name Artemis
    
    # Add a StableFPS device (if the driver is installed) using the default hardware name
    $hardware1 = Add-VmsHardware -RecordingServer $recorder -HardwareAddress http://192.168.1.101:1001 -Credential (Get-Credential) -DriverNumber 5000
    
    # Add a camera without specifying the driver and name it 'New Hardware'
    $hardware2 = Add-VmsHardware -RecordingServer $recorder -Name 'New Hardware' -Address http://192.168.1.102 -UserName root -Password notpass
    
    # Enable all camera channels on $hardware2
    foreach ($camera in $hardware2 | Get-VmsCamera) {
        $camera | Set-VmsCamera -Enabled $true
    }
    ```
* Using Import-HardwareCsv\
hardware.csv
    ```
    "HardwareName","HardwareAddress","UserName","Password"
    "Reception","http://192.168.1.102","root","notpass"
    "Shipping","http://192.168.1.103","root","notpass"
    "Parking","http://192.168.1.104","root","notpass"
    ```
    
    ```powershell
    $recorder = Get-VmsRecordingServer -Name Artemis
    Import-VmsHardware -Path hardware.csv -RecordingServer $recorder
    ```

### Save a live snapshot from all enabled cameras
```powershell
$cameras = Get-VmsCamera
foreach ($camera in $cameras) {
    $null = Get-Snapshot -Camera $camera -Live -Save -Path C:\demo\snapshots -UseFriendlyName -LocalTimestamp
}
```

<!-- ROADMAP -->
## Roadmap

See the [open issues](https://github.com/MilestoneSystemsInc/PowerShellSamples/issues) for a list of proposed features (and known issues).


<!-- CONTRIBUTING -->
## Contributing

Contributions are what make the open source community such an amazing place to be learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request



<!-- LICENSE -->
## License

Distributed under the MIT License. See `LICENSE` for more information.



<!-- CONTACT -->
## Contact

Josh Hendricks - [LinkedIn](https://www.linkedin.com/in/joshuahendricks/) - jh@milestonesys.com


<!-- ACKNOWLEDGEMENTS -->
## Acknowledgements
* [Best-README-Template by othneildrew](https://github.com/othneildrew/Best-README-Template)
* [Img Shields](https://shields.io)
* [Choose an Open Source License](https://choosealicense.com)


<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[contributors-shield]: https://img.shields.io/github/contributors/MilestoneSystemsInc/PowerShellSamples.svg?style=flat-square
[contributors-url]: https://github.com/MilestoneSystemsInc/PowerShellSamples/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/MilestoneSystemsInc/PowerShellSamples.svg?style=flat-square
[forks-url]: https://github.com/MilestoneSystemsInc/PowerShellSamples/network/members
[stars-shield]: https://img.shields.io/github/stars/MilestoneSystemsInc/PowerShellSamples.svg?style=flat-square
[stars-url]: https://github.com/MilestoneSystemsInc/PowerShellSamples/stargazers
[issues-shield]: https://img.shields.io/github/issues/MilestoneSystemsInc/PowerShellSamples.svg?style=flat-square
[issues-url]: https://github.com/MilestoneSystemsInc/PowerShellSamples/issues
[license-shield]: https://img.shields.io/github/license/MilestoneSystemsInc/PowerShellSamples.svg?style=flat-square
[license-url]: https://github.com/MilestoneSystemsInc/PowerShellSamples/blob/master/LICENSE.txt
[product-screenshot]: images/screenshot.png
