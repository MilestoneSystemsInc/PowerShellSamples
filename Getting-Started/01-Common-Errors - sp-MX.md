# Common Errors

La secuencia de comandos de instalación proporcionada en el archivo README.md de este proyecto está diseñado para protegerlo de errores comunes cuando instala cosas de la Galería de PowerShell por primera vez. A continuación se muestra una colección de estos errores, por lo que si se encuentra con ellos, sepa lo que significan y qué debe hacer.

## No se encontró ninguna coincidencia para los criterios de búsqueda y el nombre del módulo especificados

No se encontró ninguna coincidencia para los criterios de búsqueda y el nombre del módulo especificados

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

El problema no es que el nombre del módulo se haya escrito incorrectamente o que no se pueda encontrar en PSGallery. El problema es que PowerShell no pudo *conectarse* a [https://www.powershellgallery.com](https://www.powershellgallery.com) porque PSGallery requiere una conexión HTTPS usando al menos TLS 1.2, y las versiones anteriores de PowerShellGet aún usan una versión anterior de TLS o SSL.


### Solución

Para resolver esto, necesitamos decirle a PowerShell qué protocolos queremos usar. Una forma de hacerlo es ejecutar la línea bastante esotérica del código de PowerShell a continuación. Utiliza la clase .NET System.Net.ServicePointManager y modifica SecurityProtocol para incluir TLS 1.2 además de los protocolos que ya estén permitidos.

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
```

Así es como se ve después de ejecutar esto en una instancia limpia de Windows 10 Sandbox:

```powershell
PS C:\> [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
PS C:\> [Net.ServicePointManager]::SecurityProtocol
Tls11, Tls12
PS C:\>
```

## El comando se encontró en el módulo, pero el módulo no se pudo cargar

Esto es muy común en Windows 10 porque la política de ejecución predeterminada de Microsoft en Windows 10 es "Restringida". Esto significa que PowerShell no puede ejecutar *ningún* archivo *.ps1 o *.psm1. Cuando utiliza `Import-Module` para importar MilestonePSTools, o cuando usa un comando dentro del módulo como `Connect-ManagementServer`, lo primero que hace PowerShell es ejecutar el archivo .PSM1 dentro de la carpeta de instalación del módulo. Con una política de ejecución de "Restringida", PowerShell no puede cargar el módulo..

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

PowerShell suele ser bastante bueno para brindarle la información que necesita en el mensaje de error. En este caso, le recomienda ejecutar `Import-Module MilestonePSTools` para obtener más información sobre el problema. Así es como se ve eso ...

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

Puede ver que el mensaje de error más detallado hace referencia a las políticas de ejecución de manera más específica

### Solución

La forma de solucionarlo es [cambiar su política de ejecución](https:/go.microsoft.com/fwlink/?LinkID=135170).. Recomiendo leer más sobre las políticas de ejecución de Microsoft, ya que no podemos cubrir todo el tema aquí. Nuestra preferencia por una política de ejecución es cambiarla a "RemoteSigned". Esto significa que podrá ejecutar cualquier secuencia de comandos local de PowerShell, pero se requerirá que otras secuencias de comandos, descargadas de un origen de Internet que no sea de confianza, estén firmadas por un certificado de firma de código en el que ya confíe. Puede hacer que una secuencia de comandos ”remota” que no sea de confianza sea “local” y “de confianza” al hacer clic derecho en el archivo y marcando la casilla de verificación “desbloquear” en la parte inferior de la pestaña General. Si no ve esa casilla de verificación, entonces el archivo no está “bloqueado” y Windows debería permitirle ejecutar el archivo siempre que su política de ejecución sea al menos “RemoteSigned”.

Ejecute el comando `Set-ExecutionPolicy` como administrador para modificar la política en el nivel del equipo. También puede especificar un alcance de "CurrentUser" o "Process", por lo que, si tiene tiempo, le recomiendo leer la base de conocimiento de Microsoft sobre políticas de ejecución para obtener una comprensión completa de las opciones y sus implicaciones.

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
```

## Repositorio que no es de confianza

Si bien en realidad no es un error, cuando ve este mensaje por primera vez puede ser confuso. Justificadamente, es posible que se pregunte si debe proceder a instalar algo de una fuente que no sea de confianza. El repositorio de PSGallery es la [Galería de PowerShell](https://www.powershellgallery.com) administrada por Microsoft. Es una colección de miles de paquetes que contienen módulos de PowerShell como [MilestonePSTools](https://www.powershellgallery.com/packages/MilestonePSTools). De forma predeterminada, el repositorio de PSGallery incluido con el módulo PowerShellGet integrado no es de confianza. Por lo tanto, se le preguntará cada vez que necesite instalar o actualizar un módulo de este repositorio.

```powershell
PS C:\> Install-Module MilestonePSTools

Untrusted repository
You are installing the modules from an untrusted repository. If you trust this repository, change its
InstallationPolicy value by running the Set-PSRepository cmdlet. Are you sure you want to install the modules from
'PSGallery'?
```

### SoluSolucióntion

Puede optar por reconocer este mensaje cada vez o puede establecer la `Política de instalación` para el repositorio en "De confianza". A continuación, le indicamos cómo hacerlo:

```powershell
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
```
