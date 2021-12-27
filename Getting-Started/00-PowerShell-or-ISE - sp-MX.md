# PowerShell o ISE?

En un sistema operativo Windows estándar, normalmente tiene dos opciones para usar PowerShell. Tiene más opciones si considera las variantes x86 (32 bits). Cuando está comenzando, puede ser difícil saber cuál usar y porqué. Cuando hace clic en el botón del menú Inicio o presiona su tecla de Windows (<kbd>⊞</kbd>), y escribe "powershell", esto es lo que obtiene...

![Captura de pantalla del menú Inicio que muestra PowerShell](https://github.com/MilestoneSystemsInc/PowerShellSamples/blob/main/Getting-Started/images/Start-Menu.png?raw=true)

## PowerShell de Windows

Esta es su opción de acceso para ingresar un comando a la vez para realizar una tarea simple y única. No es ideal para escribir secuencias de comandos más largos y complejas, ya que cada vez que presione <kbd>Enter</kbd> evaluará lo que ha escrito y lo ejecutará. A menudo uso el terminal de Windows PowerShell para ejecutar comandos individuales como `ping`, y `Test-NetConnection`, o en ocasiones para tareas únicas que requieren varios comandos que me siento cómodo ejecutando en una terminal en lugar de un editor como ISE.

![Captura de pantalla de Windows PowerShell](https://github.com/MilestoneSystemsInc/PowerShellSamples/blob/main/Getting-Started/images/Windows-PowerShell.png?raw=true)

## Windows PowerShell ISE

El Entorno de Scripting Integrado (ISE) PowerShell se incluye en todas las versiones de Windows y proporciona un entorno fácil de usar para escribir scripts en un editor de texto y ejecutar esas secuencias de comandos en la misma interfaz. Aquí es donde desea estar si desea crear una secuencia de comandos de PowerShell. Puede utilizar el Bloc de notas para escribir un archivo .PS1, pero PowerShell ISE ofrece tabulación completa e "Intellisense". Intellisense es como un compañero de desarrollador que conoce todos los parámetros disponibles para cualquier comando que esté escribiendo, por lo que tan pronto como escriba "-" después de `Get-ChildItem` le mostrará todos los parámetros disponibles.

También puede ejecutar una o más líneas de código a la vez con <kbd>F8</kbd> o ejecutar todo el archivo con <kbd>F5</kbd>. Cuando se sienta cómodo con PowerShell como lenguaje y el entorno ISE, incluso puede agregar puntos de interrupción y *depurar* sus secuencias de comandos cuando lo hagan de forma inesperada.

Hay mejores entornos para escribir código de PowerShell que el ISE. Por ejemplo, Visual Studio Code es un editor *gratuito* de Microsoft con extensiones para PowerShell que lo convierten en un entorno mucho más productivo para proyectos de PowerShell más grandes. Sin embargo, el ISE está disponible en *todos* los equipos con Windows y ofrece el punto de partida menos intimidante para la ruta de aprendizaje de PowerShell.

![Captura de pantalla de PowerShell ISE](https://github.com/MilestoneSystemsInc/PowerShellSamples/blob/main/Getting-Started/images/PowerShell-ISE.png?raw=true)

## Windows PowerShell (x86) y Windows PowerShell ISE (x86)

Estos son los equivalentes de 32 bits de los mismos dos entornos de PowerShell ya mencionados. Los entornos estándar de PowerShell son de 64 bits y rara vez necesitará un entorno de 32 bits, pero si lo necesita, lo tiene. Puesto que el MIP SDK de Milestone se proporciona principalmente como paquetes NuGet de 64 bits y el MIP SDK de 32 bits está en desuso, necesitará un entorno Windows PowerShell 5.1 de 64 bits para usar el módulo MilestonePSTools PowerShell.

## Visual Studio Code

VSCode de Microsoft es un entorno fantástico para trabajar en muchos tipos de proyectos, desde PowerShell hasta HTML/CSS/JavaScript, Python y más. Es un editor de texto con extensiones que lo convierten en un entorno cómodo para trabajar con múltiples archivos de diferentes tipos, e incluso ejecutar código. Es una parte integral del mantenimiento de MilestonePSTools y otros proyectos de PowerShell en los que hemos trabajado y, a medida que se sienta más cómodo con PowerShell, le recomiendo que lo pruebe. La siguiente secuencia de comandos automatizará la instalación de código, así como mis extensiones favoritas para trabajar con PowerShell y GitHub.

![Captura de pantalla de Visual Studio Code](https://github.com/MilestoneSystemsInc/PowerShellSamples/blob/main/Getting-Started/images/VSCode.png?raw=true)

```powershell
$InformationPreference = 'Continue'
$requestParams = @{
    Uri = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64"
    OutFile = Join-Path $env:TEMP VSCodeUserSetup.exe
}
Write-Information "Downloading VSCode from $($requestParams.Uri)"
Invoke-WebRequest @requestParams

if (-not (Test-Path -Path $requestParams.OutFile)) {
    throw "Could not find the downloaded installer at $($requestParams.OutFile)"
}

Write-Information 'Installing VSCode from $($requestParams.OutFile). . .'
$installerArgs = @{
    FilePath = $requestParams.OutFile
    Wait = $true
    NoNewWindow = $true
    PassThru = $true
    ErrorAction = 'Stop'
    ArgumentList = @(
    '/verysilent',
    '/suppressmsgboxes',
    '/mergetasks="!runCode, desktopicon, quicklaunchicon, addcontextmenufiles, addcontextmenufolders, associatewithfiles, addtopath"'
    )
}
$result = Start-Process @installerArgs
Remove-Item -Path $requestParams.OutFile -Force
if ($result.ExitCode -notin @(0, 1641, 3010)) {
    throw "VSCode installer exited with code $($result.ExitCode)"
}
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
Write-Information "Success! VSCode version $(code --version)"

Write-Information "Installing a couple important VSCode extensions. Some other fun ones include Rainbow Brackets, indent-rainbox, Live Share*, and markdownlint."
$extensions = @(

)
$extensions = @(
    'ms-vscode.powershell',
    'github.vscode-pull-request-github',
    'davidanson.vscode-markdownlint',
    'usernamehw.errorlens'
)
$extensions | Foreach-Object { code --install-extension $_ --force }

Write-Information 'Done! Type "code" to open VSCode or "code ." to open the current directory in VSCode.'
```
