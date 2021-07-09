# PowerShell or ISE?

On an standard Windows operating system you typically have two choices for how to use PowerShell. More if you consider the x86 (32-bit) variants! When you''re getting started, it's difficult to know which to use, and why. When you click the Start menu button or press your Windows key (<kbd>⊞</kbd>), and type "powershell", here''s what you get...

![Start Menu screenshot showing PowerShell](https://github.com/MilestoneSystemsInc/PowerShellSamples/blob/main/Getting-Started/images/Start-Menu.png?raw=true)

## Windows PowerShell

This is your go-to option for entering one command at a time to perform a simple, one-time task. It''s not great for writing out longer, complex scripts since every time you press <kbd>Enter</kbd> it will evaluate what you''ve typed and run it. I often use the Windows PowerShell terminal to run single commands like `ping`, and `Test-NetConnection`, or sometimes for one-off tasks that require multiple commands that I''m comfortable running in a terminal instead of an editer like ISE.

![Windows PowerShell screenshot](https://github.com/MilestoneSystemsInc/PowerShellSamples/blob/main/Getting-Started/images/Windows-PowerShell.png?raw=true)

 ## Windows PowerShell ISE

 The PowerShell Integrated Scripting Environment (ISE) is included in all versions of Windows and provides you with a user-friendly environment to write scripts in a text editor, and run those scripts in the same interface. This is where you want to be if you want to craft a PowerShell script. You can use Notepad to write a .PS1 file, but PowerShell ISE offers tab-completion and "Intellisense". Intellisense is like a developer side-kick who knows all the parameters available for whatever command you''re writing, so as soon as you type "-" after `Get-ChildItem` it will show you all the available parameters you can use.

 You can also run one or more lines of code at a time using <kbd>F8</kbd> or run the whole file using <kbd>F5</kbd>. When you get comfortable with PowerShell as a language, and the ISE environment, you can even add break points and *debug* your scripts when they do the unexpected.

 There are better environments to write PowerShell code in than the ISE. For instance, Visual Studio Code is a *free* editor from Microsoft with extensions for PowerShell which make it a far more productive environment for larger PowerShell projects. However, the ISE is available on *every* Windows computer and offers the least intimidating starting point for your PowerShell learning path.

 ![PowerShell ISE screenshot](https://github.com/MilestoneSystemsInc/PowerShellSamples/blob/main/Getting-Started/images/PowerShell-ISE.png?raw=true)

## Windows PowerShell (x86) and Windows PowerShell ISE (x86)

These are the 32-bit equivalents of the same two PowerShell environments already mentioned. The standard PowerShell environments are 64-bit and you will rarely need a 32-bit environment but if you need it, you have it. Since the Milestone MIP SDK is provided primarily as 64-bit NuGet packages and the 32-bit MIP SDK is deprecated, you will require a 64-bit Windows PowerShell 5.1 environment to use the MilestonePSTools PowerShell module.

## Visual Studio Code

Microsoft''s VSCode is a fantastic environment for working on many different kinds of projects from PowerShell, to HTML/CSS/JavaScript, to Python and more. It''s a text editor with extensions which make it a comfortable environment for working with multiple files of different types, and even running/executing code. It''s an integral part of the maintenance of MilestonePSTools and other PowerShell projects we''ve worked on and as you get more comfortable with PowerShell, I highly recommend trying it out. The script below will automate the installation of code, as well as my favorite extensions for working with PowerShell and GitHub.

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
