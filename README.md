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
* PowerShell 5.1 or newer. Use `$PSVersionTable` to determine the PSVersion of your current PowerShell terminal

### Installation

You can install MilestonePSTools on the computer where your Milestone VMS is installed, but that is not required. In fact, from a security standpoint it is best to avoid installing software on the same server as your VMS if it's not necessary. Just as the XProtect Smart Client and Management Client may be used from a networked PC, so too can MilestonePSTools be used from a remote system.

1. Check PowerShell Execution Policy and consider switching to RemoteSigned if currently set to 'Restricted'
```powershell
Get-ExecutionPolicy
Set-ExecutionPolicy RemoteSigned
```
1b. Microsoft have improved security on their PSGallery repository. If you install MilestonePSTools using the Install-Module cmdlet, you might need to run the following to ensure TLS 1.2 is used for communication with PSGallery. Otherwise you may see a variety of different possible error messages when attempting to run Install-Module.
```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 
Install-Module PowerShellGet -RequiredVersion 2.2.4 -SkipPublisherCheck
```
2. Trust the PSGallery repository (optional)
```powershell
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
```
3. Install MilestonePSTools for your Windows profile
```powershell
Install-Module MilestonePSTools -Scope CurrentUser
```

<!-- USAGE EXAMPLES -->
## Usage
### Get connected
* Connect with the current Windows user
    ```powershell
    Connect-ManagementServer -Server myvms -AcceptEula
    ```
* Connect with a Windows or Active Directory user
    ```powershell
    Connect-ManagementServer -Server myvms -Credential (Get-Credential) -AcceptEula
    ```
* Connect with a Milestone Basic User
    ```powershell
    Connect-ManagementServer -Server myvms -Credential (Get-Credential) -BasicUser -AcceptEula
    ```

### List all enabled cameras
```powershell
# Slower but uses Configuration API so each object can be used to modify configuration
Get-Hardware | Where-Object Enabled | Get-Camera | Where-Object Enabled | Select Name

# Faster but provides limited access to camera properties and Items cannot be used to modify configuration
Get-PlatformItem -Kind (Get-Kind -List | ? DisplayName -eq Camera).Kind | Select Name
```

### Add hardware
* Using Add-Hardware
    ```powershell
    # Select a Recording Server by name
    $recorder = Get-RecordingServer -Name Artemis
    
    # Add a StableFPS device (if the driver is installed) using the default hardware name
    $hardware1 = Add-Hardware -RecordingServer $recorder -Address http://192.168.1.101:1001 -UseDefaultCredentials -DriverId 5000 -GroupPath /StableFPS
    
    # Add a camera without specifying the driver, name it 'New Camera' and place it in a Camera Group named 'New Cameras'
    $hardware2 = Add-Hardware -RecordingServer $recorder -Name 'New Camera' -Address http://192.168.1.102 -UserName root -Password notpass -GroupPath '/New Cameras'
    
    # Enable all camera channels on $hardware2
    foreach ($camera in $hardware2 | Get-Camera) {
        $camera.Enabled = $true
        $camera.Save()
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
    $recorder = Get-RecordingServer -Name Artemis
    Import-HardwareCsv -Path hardware.csv -RecordingServer $recorder
    ```

### Save a live snapshot from all cameras
```powershell
$cameras = Get-Hardware | ? Enabled | Get-Camera | ? Enabled
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
