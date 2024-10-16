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

  <h3 align="center">Gestionar Milestone con PowerShell</h3>

  <p align="center">
    Una colección de secuencia de comandos de ejemplo para iniciar su aventura de gestión de VMS XProtect de Milestone
    <br />
    <a href="https://github.com/MilestoneSystemsInc/PowerShellSamples"><strong>Explore los ejemplos»</strong></a>
    <br />
    <br />
    <a href="https://github.com/MilestoneSystemsInc/PowerShellSamples/issues">Reporte un problema</a>
    ·
    <a href="https://github.com/MilestoneSystemsInc/PowerShellSamples/issues">Solicite una funcion</a>
  </p>
</p>



<!-- TABLE OF CONTENTS -->
## Índice

* [Acerca del proyecto](#about-the-project)
* [Introducción](#getting-started)
  * [Requisitos previos](#prerequisites)
  * [Instalación](#installation)
* [Uso](#usage)
* [Hoja de ruta](#roadmap)
* [Contribución](#contributing)
* [Licencia](#license)
* [Contacto](#contact)
* [•	Agradecimientos](#acknowledgements)



<!-- ABOUT THE PROJECT -->
## Acerca del proyecto

Este repositorio contiene secuencias de comandos de ejemplo de PowerShell para gestionar y automatizar tareas relacionadas con el software VMS XProtect de Milestone mediante MilestonePSTools. Se pretende que sea un complemento de la documentación incorporada disponible en muchos cmdlets de MilestonePSTools a los que puede acceder mediante `Get-Help`.

[![Product Name Screen Shot][product-screenshot]]()

<!-- GETTING STARTED -->
## Introducción

Para aprovechar al máximo MilestonePSTools, necesitará al menos cierta familiaridad básica con PowerShell u otros shells. Es posible realizar algunas acciones muy básicas en unas pocas líneas de PowerShell con experiencia limitada. Con un poco más de experiencia y ambición, es posible desarrollar herramientas extensas y poderosas o módulos completos para automatizar importantes tareas comerciales y de mantenimiento exclusivas de su organización.

[![IMAGE ALT TEXT](http://img.youtube.com/vi/qZ-I-Imm7tk/0.jpg)](http://www.youtube.com/watch?v=qZ-I-Imm7tk "MilestonePSTools Demo")

Si es nuevo en PowerShell, existe una amplia gama de recursos disponibles para aprender. Un ejemplo popular es la serie [Aprenda Windows PowerShell en un mes de almuerzos](https://www.youtube.com/playlist?list=PL6D474E721138865A) que, aunque se actualizó por última vez en 2014, sigue siendo un buen recurso para aprender la sintaxis y el estilo.

### Requisitos previos

MilestonePSTools se desarrolla utilizando la última versión del MIP SDK de Milestone. Como tal, tiene los siguientes requisitos previos:
* VMS XProtect de Milestone (XProtect Essential+, Express+, Professional+, Expert, o Corporate) 2014 o posterior
* Edición de escritorio/servidor de Windows (no compatible con PowerShell Core)
* .NET Framework 4.7
* PowerShell 5.1. Utilice `$PSVersionTable` para determinar la PSVersion de su terminal PowerShell actual: si necesita actualizar PowerShell, descargue Windows [Management Framework 5.1](https://www.microsoft.com/en-us/download/details.aspx?id=54616) de Microsoft

### Instalación

Puede instalar MilestonePSTools en el equipo donde está instalado su VMS de Milestone, pero no es necesario. De hecho, desde el punto de vista de la seguridad, es mejor evitar la instalación de software en el mismo servidor que su VMS si no es necesario. Así como XProtect Smart Client y el cliente de gestión se pueden utilizar desde una PC en red, MilestonePSTools también se puede utilizar desde un sistema remoto.

Puede copiar y pegar la siguiente secuencia de comandos en PowerShell, o PowerShell ISE, y mientras tenga PowerShell 5.1 instalado, debería funcionar.


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

### Caramba, eso es mucho PowerShell

La secuencia de comandos anterior puede parecer intimidante, y __nunca__ debe copiar y pegar código de ningún tipo si no sabe lo que hace. En resumen, la secuencia de comandos está diseñada para que sea lo más fácil y rápido posible instalar MilestonePSTools. A veces, su entorno de PowerShell necesita algunos ajustes y actualizaciones para poder instalar los módulos de PowerShell. ¡Vamos a desglosar lo que realmente hace, en caso de que su jefe lo solicite!

1. Se inicia una secuencia de comandos en una nueva instancia de PowerShell que requiere elevación. Entonces:
2. Configura el protocolo de seguridad HTTPS en TLS 1.2, que es necesario para comunicarse con [PSGallery](https://powershellgallery.com).
3. Establece la política de ejecución en `RemoteSigned`. El valor predeterminado en Windows 10 es Restringido y eso le impedirá usar cualquier módulo de PowerShell. `RemoteSigned` significa que cualquier secuencia de comandos que esté “bloqueada” debe estar firmada.
4. Registra [NuGet.org](https://www.nuget.org) como fuente de paquete. Esto no es estrictamente necesario, pero puede ser útil si usted necesita instalar paquetes .NET desde PowerShell, y en el futuro podemos actualizar MilestonePSTools para que dependa de los paquetes oficiales de [MIP SDK NuGet packages](https://www.nuget.org/profiles/milestonesys).
5. Instala el proveedor de paquetes NuGet que usa PowerShellGet como fuente para instalar módulos de PowerShell. Es posible que usted tenga una versión anterior de PowerShellGet, por lo que esto garantizará que se actualice.
6. Establece el repositorio de PSGallery como una fuente confiable para los módulos de PowerShell. Esto no es obligatorio, pero evitará que tenga que reconocer cada módulo que usted instale.
7. Actualizaciones del módulo PowerShellGet más reciente
8. Instala/actualiza MilestonePSTools to `C:\Program Files\WindowsPowerShell\Modules\`

<!-- USAGE EXAMPLES -->
## Uso
### Conéctese
* Si ya existe un perfil de conexión de Milestone denominado "default", se establecerá una conexión con la dirección del servidor de administración en ese perfil de conexión. Si no existe dicho perfil, se mostrará un cuadro de diálogo de inicio de sesión de Milestone. El parámetro "-AcceptEula" solo es necesario la primera vez que el usuario de Windows actual usa el comando. Si el comando se usa más adelante con una cuenta de usuario de Windows diferente, el parámetro "-AcceptEula" será
necesario una vez para ese usuario.
    ```powershell
    Connect-Vms -AcceptEula
    ```
* Si ya existe un perfil de conexión de Milestone llamado "MyVMS", se establecerá una conexión con la dirección del servidor de administración en ese perfil de conexión. Si no existe dicho perfil, se mostrará un cuadro de diálogo de inicio de sesión de Milestone. Al iniciar sesión correctamente, el perfil nombrado se guardará en el disco y, al llamar a 'Connect-Vms -Name MyVMS' en el futuro, se conectará automáticamente a la misma dirección del servidor con las mismas credenciales.
    ```powershell
    Connect-Vms -Name 'MyVMS'
    ```
* Solicite una credencial de Windows o Active Directory y luego establezca una conexión a http://MyVMS. Una vez que la conexión se haya realizado correctamente, se agregará o actualizará un perfil de conexión llamado "MyVMS".
    ```powershell
    Connect-Vms -Name 'MyVMS' -ServerAddress 'http://MyVMS' -Credential 
    ```
* Muestra un cuadro de diálogo de inicio de sesión de Milestone y, tras una conexión exitosa, agrega o actualiza el perfil de conexión llamado "MyVMS".
    ```powershell
    Connect-Vms -Name 'MyVMS' -ShowDialog
    ```
* Solicite una credencial de usuario básico y luego establezca una conexión a http://MyVMS.
    ```powershell
    Connect-Vms -ServerAddress 'http://MyVMS' -Credential (Get-Credential) -BasicUser
    ```

### Enumerar todas las cámaras habilitadas
```powershell
# Más lento pero usa la Configuración de API, por lo que cada objeto se puede usar para modificar la configuración
Get-VmsCamera | Select Name

# Más rápido, pero proporciona acceso limitado a las propiedades de la cámara y los elementos no se pueden utilizar
# para modificar la configuración
Get-PlatformItem -Kind (Get-Kind -List | ? DisplayName -eq Camera).Kind | Select Name
```

### Agregar hardware
* Using Add-Hardware
    ```powershell
    # Seleccione un servidor de grabación por nombre
    $recorder = Get-VmsRecordingServer -Name Artemis

    # Agregue un dispositivo StableFPS (si el driver está instalado) usando el nombre de hardware predeterminado
    $hardware1 = Add-VmsHardware -RecordingServer $recorder -HardwareAddress http://192.168.1.101:1001 -Credential (Get-Credential) -DriverNumber 5000

    # Agregue una cámara sin especificar el driver, asígnele el nombre “Hardware nueva” y colóquela en un Grupo de cámaras llamado 'Cámaras nuevas'
    $hardware2 = Add-VmsHardware -RecordingServer $recorder -Name 'New Hardware' -Address http://192.168.1.102 -UserName root -Password notpass

    # Habilite todos los canales de la cámara en $hardware2
    foreach ($camera in $hardware2 | Get-VmsCamera) {
        $camera | Set-VmsCamera -Enabled $true
    }
    ```
* Uso de Import-HardwareCsv\
hardware.csv
    ```
    "HardwareName","HardwareAddress","UserName","Password"
    "Reception","http://192.168.1.102","root","notpass"
    "Shipping","http://192.168.1.103","root","notpass"
    "Parking","http://192.168.1.104","root","notpass"
    ```

    ```powershell
    $recorder = Get-RecordingServer -Name Artemis
    Import-VmsHardware -Path hardware.csv -RecordingServer $recorder
    ```

### Guardar una instantánea en vivo de todas las cámaras habilitadas
```powershell
$cameras = Get-VmsCamera
foreach ($camera in $cameras) {
    $null = Get-Snapshot -Camera $camera -Live -Save -Path C:\demo\snapshots -UseFriendlyName -LocalTimestamp
}
```

<!-- ROADMAP -->
## Hoja de ruta

Consulte los [problemas abiertos](https://github.com/MilestoneSystemsInc/PowerShellSamples/issues) para obtener una lista de las características propuestas (y los problemas conocidos).


<!-- CONTRIBUTING -->
## Contribuir

Las contribuciones son las que hacen de la comunidad de código abierto un lugar tan increíble para aprender, inspirar y crear. Cualquier contribución que haga **es muy apreciada**.

1. Bifurcar el proyecto
2. Crear la rama de características (`git checkout -b feature/AmazingFeature`)
3. Confirme sus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Empuje a la sucursal (`git push origin feature/AmazingFeature`)
5. Abrir una solicitud de extracción

<!-- LICENSE -->
## Licencia

Distribuido bajo la Licencia MIT. Consulte `LICENCIA` para obtener más información.

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
