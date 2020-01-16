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

You can install MilestonePSTools on the computer where your Milestone VMS is installed, but that is not required. In fact, from a security standpoint it is best to avoid installing software on the same server as your VMS if it's not necessary. Just as the XProtect Smart Client and Management Client may be used from a networked PC, so to can MilestonePSTools be used from a remote system.

1. Check PowerShell Execution Policy and consider switching to RemoteSigned if currently set to 'Restricted'
```powershell
Get-ExecutionPolicy
Set-ExecutionPolicy RemoteSigned
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

The examples provided in this repository will demonstrate the usage of MilestonePSTools. However, most cmdlets require that you use `Connect-ManagementServer` to establish a login session with your VMS Management Server.

```powershell

NAME
    Connect-ManagementServer
    
SYNOPSIS
    Connects to a Milestone XProtect VMS Management Server
    
    
SYNTAX
    Connect-ManagementServer [[-Server] <string>] [[-Credential] <PSCredential>] [[-BasicUser] <SwitchParameter>] 
    [[-AcceptEula] <SwitchParameter>] [[-IncludeChildSites] <SwitchParameter>] [[-WcfProxyTimeoutSeconds] <int>] 
    [-Port <int>] [<CommonParameters>]
    
    
DESCRIPTION
    The Connect-ManagementServer cmdlet is the first cmdlet used when working with MilestonePSTools to explore or 
    modify a Milestone XProtect VMS.
    
    Authentication methods include Windows, Active Directory, or Basic users, and Milestone Federated Architecture is 
    supported when using anything besides Basic authentication. The state of the session with the Management Server 
    will be maintained in the background for the duration of the PowerShell session, or until 
    Disconnect-ManagementServer is used.
    
    By default, this cmdlet will only authenticate with the Management Server provided in the -Server parameter. If 
    child sites need to be accessed during the same session, you should supply the -IncludeChildSites switch, and use 
    the Select-Site cmdlet to switch between sites
    
    Note: If you do not supply a Credential object, the current Windows user will be used for authentication 
    automatically.
    

PARAMETERS
    -Server <string>
        Specifies, as an IP, hostname, or FQDN, the address of the Milestone XProtect Management Server.
        
        Required?                    false
        Position?                    1
        Default value                localhost
        Accept pipeline input?       false
        Accept wildcard characters?  false
        
    -Port <int>
        Specifies, as an integer between 1-65535, the HTTP port of the Management Server. Default is 80.
        
        Note: When using basic authentication and a custom HTTP port on the Management Server, leave this value alone. 
        MIP SDK will automatically use HTTPS on port 443.
        
        Required?                    false
        Position?                    named
        Default value                80
        Accept pipeline input?       false
        Accept wildcard characters?  false
        
    -Credential <PSCredential>
        Specifies the username and password of either a Windows/AD or Milestone-specific Basic user. If the 
        credentials are for a basic user, you must also supply the -BasicUser switch parameter. If this Credential 
        parameter is omitted, the current Windows user credentials running the PowerShell session will be used by 
        default.
        
        Required?                    false
        Position?                    2
        Default value                
        Accept pipeline input?       false
        Accept wildcard characters?  false
        
    -BasicUser <SwitchParameter>
        Uses Basic User authentication. Use only to authenticate Basic Users which are users specific to Milestone and 
        do not correspond to a Windows or Active Directory user account.
        
        Required?                    false
        Position?                    5
        Default value                False
        Accept pipeline input?       false
        Accept wildcard characters?  false
        
    -AcceptEula <SwitchParameter>
        Acknowledge you have read and accept the end-user license agreement for the redistributable MIP SDK package
        
        Required?                    false
        Position?                    6
        Default value                False
        Accept pipeline input?       false
        Accept wildcard characters?  false
        
    -IncludeChildSites <SwitchParameter>
        Authenticates with the supplied Management Server, and all child Management Servers in a given Milestone 
        Federated Architecture tree.
        
        Required?                    false
        Position?                    7
        Default value                False
        Accept pipeline input?       false
        Accept wildcard characters?  false
        
    -WcfProxyTimeoutSeconds <int>
        Specifies, as an integer value representing seconds, the maximum timeout value for any Milestone Configuration 
        API operation.
        
        The Configuration API utilizes Windows Communication Foundation to establish a secure communication channel, 
        and provides extensive access to Milestone XProtect VMS configuration elements.
        
        Most operations should complete very quickly, but in some environments it is possible for operations to take 
        several minutes to complete.
        
        Default value is 300 seconds, or 5 minute.-
        
        Required?                    false
        Position?                    8
        Default value                300
        Accept pipeline input?       false
        Accept wildcard characters?  false
        
    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see 
        about_CommonParameters (https:/go.microsoft.com/fwlink/?LinkID=113216). 
    
INPUTS
    
OUTPUTS
    
    ----------  EXAMPLE 1  ----------
    
    C:\PS>Connect-ManagementServer -Server mgtsrv1
    
    This command authenticates with a server named mgtsrv1 where the server is listening on HTTP port 80, and it uses 
    the current PowerShell user context.
    
    If you have opened PowerShell normally, as your current Windows user, then the credentials used will be that of 
    your current Windows user.
    
    If you have opened PowerShell as a different user (shift-right-click, run as a different user), OR you are 
    executing your script as a scheduled task, the user context will be that of whichever user account was used to 
    start the PowerShell session.
    
    
    
    ----------  EXAMPLE 2  ----------
    
    C:\PS>Connect-ManagementServer -Server mgtsrv1 -Credential (Get-Credential)
    
    This command will prompt the user for a username and password, then authenticates with a server named mgtsrv1 
    where the server is listening on HTTP port 80 using Windows authentication.
    
    
    
    ----------  EXAMPLE 3  ----------
    
    C:\PS>Connect-ManagementServer -Server mgtsrv1 -Credential (Get-Credential) -BasicUser
    
    This command authenticates with a server named mgtsrv1 where the server is listening on HTTPS port 443, and it 
    authenticates a basic user using the credentials supplied in the Get-Credential pop-up
    
    Note: As a "Basic User", the user will not have access to child sites in a Milestone Federated Architecture and 
    thus the -IncludeChildSites switch will not have any effect.
    
    
    
    
RELATED LINKS

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