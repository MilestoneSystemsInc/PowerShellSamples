[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]


<!-- PROJECT LOGO -->
<br />
<p align="center">
  <a href="https://github.com/MilestoneSystemsInc/PowerShellSamples">
    <img src="images/logo.png" alt="Logo" width="80" height="80">
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
  * [Built With](#built-with)
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

[![Product Name Screen Shot][product-screenshot]]()

This repository contains sample PowerShell scripts for managing and automating tasks related to Milestone XProtect VMS software using MilestonePSTools.
There are many great README templates available on GitHub, however, I didn't find one that really suit my needs so I created this enhanced one. I want to create a README template so amazing that it'll be the last one you ever need.

Here's why:
* Your time should be focused on creating something amazing. A project that solves a problem and helps others
* You shouldn't be doing the same tasks over and over like creating a README from scratch
* You should element DRY principles to the rest of your life :smile:

Of course, no one template will serve all projects since your needs may be different. So I'll be adding more in the near future. You may also suggest changes by forking this repo and creating a pull request or opening an issue.

A list of commonly used resources that I find helpful are listed in the acknowledgements.

### Built With
* [MilestonePSTools](https://www.powershellgallery.com/packages/MilestonePSTools)



<!-- GETTING STARTED -->
## Getting Started

This is an example of how you may give instructions on setting up your project locally.
To get a local copy up and running follow these simple example steps.

### Prerequisites

MilestonePSTools is developed using the latest build of Milestone's MIP SDK. As such, it has the following prerequisits:
* Windows Desktop/Server edition (not compatible with PowerShell Core)
* .NET Framework 4.7
* npm
```sh
npm install npm@latest -g
```

### Installation

1. Check your PowerShell version and install [Windows Management Framework 5.1](https://www.microsoft.com/en-us/download/details.aspx?id=54616) if PSVersion is less than 5.1
```powershell
$PSVersionTable
```
2. Check PowerShell Execution Policy and consider switching to RemoteSigned if currently set to 'Restricted'
```powershell
Get-ExecutionPolicy
Set-ExecutionPolicy RemoteSigned
```
3. Trust the PSGallery repository (optional)
```powershell
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
```
4. Install MilestonePSTools for your Windows profile
```powershell
Install-Module MilestonePSTools -Scope CurrentUser
```



<!-- USAGE EXAMPLES -->
## Usage


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