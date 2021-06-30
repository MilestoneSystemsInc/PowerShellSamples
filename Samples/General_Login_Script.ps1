###################################################################################################
#
# This login script can be placed in front of any other script or used standalone to simplify the
# login process for a user that isn't as familiar with PowerShell as other users.  It will prompt
# for the IP address or hostname of the Management Server, then it will ask what user type,
# and then it asks for the credentials and completes the login process.
#
###################################################################################################

##### Start Login Script #####

Import-Module MilestonePSTools
$currentErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Stop"

# Checks to see if the MIP SDK EULA has been accepted already.  If it hasn't, it asks them to accept it.
if ((Test-Path "$($env:USERPROFILE)\AppData\Roaming\MilestonePSTools\user-accepted-eula.txt") -ne $true)
{
    do
    {
        Write-Host "Have you read and agree to the End User License Agreement for the Milestone Redistributable MIP SDK? (Y or N): " -NoNewline -ForegroundColor Green
        $eulaAcceptance = Read-Host
        Switch ($eulaAcceptance)
        {
            "Y" {Continue}
            "N" {
                    Invoke-MipSdkEula
                }
            Default
                {
                    Write-Host "Invalid input. Please try again." -ForegroundColor White -BackgroundColor Red -NoNewline
                }
        }
    } while ($eulaAcceptance -ne "Y")
}

Write-Host 'Please enter IP Address or hostname of the Management Server (leave blank for "localhost"): ' -NoNewline -ForegroundColor Green
$server = Read-Host

# If no server name was entered then set $server to localhost
if ([string]::IsNullOrWhiteSpace($server))
{
    $server = "localhost"
}

# Sets $userType to the appropriate user type based on the input of 1, 2, or 3 requested above.
do
{
    $userType = ""
    Write-Host "`nPlease enter your user type (without quotes).  Enter `"1`" for Windows Authentication (current user), enter `"2`" for Windows Authentication, or enter `"3`" for Basic User: " -NoNewline -ForegroundColor Green
    $auth = Read-Host
    Switch ($auth)
    {
        1 {$userType = "CurrentUser"; break}
        2 {$userType = "WindowsUser"; break}
        3 {$userType = "BasicUser"; break}
        Default
        {
            Write-Host "Invalid input. Please try again." -ForegroundColor White -BackgroundColor Red -NoNewline
        }
    }
} while ((($auth -ne 1) -and ($auth -ne 2) -and ($auth -ne 3)))

Write-Host "`nConnecting to Management Server.`n" -ForegroundColor Green

try
{
    # If $userType equals WindowsUser or BasicUser, prompt for credentials.
    if ($userType -eq "WindowsUser" -or $userType -eq "BasicUser")
    {
        switch ($userType)
        {
            "WindowsUser" {Connect-ManagementServer -Server $server -Credential (Get-Credential) -AcceptEula -Force}
            "BasicUser" {Connect-ManagementServer -Server $server -Credential (Get-Credential) -AcceptEula -BasicUser -Force}
        }
    }
    else
    {
        Connect-ManagementServer -Server $server -AcceptEula
    }
}

catch
{
    $categoryError = $_.CategoryInfo
    switch ($categoryError.Reason)
    {
        "ServerNotFoundMIPException" {Write-Host "Server $($server) not found.  Please try again." -ForegroundColor Red}
        "InvalidCredentialsMIPException" {Write-Host "Authentication error.  Please try again." -ForegroundColor Red}
    }
    Exit
}

finally
{
    $ErrorActionPreference = $currentErrorActionPreference
}

$ms = Get-ManagementServer -ErrorAction Ignore
if ($null -ne $ms)
{
    Write-Host "`nSuccessfully connected to Management Server" -ForegroundColor Green
}

##### End Login Script #####