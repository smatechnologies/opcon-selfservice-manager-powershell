<#
The purpose of this script is to provide a framework for managing OpCon in a terminal.

v1.7 - Removed functions from script driver to fix issues with menu.  Fixed bug with buttons and roles.
       Added a few checks in authentication process to make sure to check for bad logins.
v1.6 - Total rewrite to encompass a framework for the GUI.  Imports/Saves logins and allows
       import/export of buttons to a file for mass changes.
v1.5 - Added button to check expressions in source.  Added Hide/Disable output.  Message fixes.
v1.4 - Bug fixes, UX improvements and ability to flip environments
v1.3 - Added ability to move category of buttons
v1.2 - Bug fixes for category checks and added logging
v1.15 - Updated the menu bar and checkbox locations.
v1.1 - Added logic/options to run from a command line.  Also various bug fixes.
v1.0 - Initial release
#>

param (
    [switch] $cli,
    $srcUrl, # URL to Source OpCon API ie https://<opconserver>:<port>
    $destUrl, # URL to Destination OpCon API
    $button, # Button name
    $category, # Category name
    $srcUser, # Used for API authentication
    $srcPassword, # Used for API authentication, recommend passing in as an encrypted global property
    $destUser, # Used for API authentication
    $destPassword, # Used for API authentication, recommend passing in as an encrypted global property
    $srcToken, # Used to specify an existing API token
    $destToken, # Used to specify an existing API token
    $OpConModule = "C:\Github\OpCon_API\Module\OpConModule.psm1"
)

$global:version = "1.7"

# Verify PS version is at least 7
if($PSVersionTable.PSVersion.Major -ge 7)
{
    # Import the OpCon functions
    if(Test-Path $opconModule)
    {
        Import-Module -Name $opconModule -Force

        # Skip self signed certificates
        OpCon_SkipCerts

        # Check if CLI before starting terminal
        if(!$cli)
        { 
            # Store script path for logging purposes
            $global:path = Split-Path -parent $MyInvocation.MyCommand.Definition

            # Start main OpConsole program
            Import-Module ($global:path + "\OpConsole_Login_Module.psm1") -Force
            Import-Module ($global:path + "\OpConsole_CheckExpression.psm1") -Force
            Import-Module Microsoft.PowerShell.ConsoleGuiTools -Force
            $module = (Get-Module Microsoft.PowerShell.ConsoleGuiTools -List).ModuleBase
            Add-Type -Path (Join-path $module Terminal.Gui.dll)
            [Terminal.Gui.Application]::Init()

            # Import Logins
            OpConsole_Import_Logins
        
            # Application
            $Window = [Terminal.Gui.Window]::new()
            $Window.Title = "OpConsole (v" + $global:version + ")"
            $Window.add_KeyPress({ param($arg) 
                if($arg.KeyEvent.Key.ToString() -eq "F2")
                { $global:MenuBar.OpenMenu() }
            })
            [Terminal.Gui.Application]::Top.Add($Window)

            OpConsole -window $Window
        }
        else 
        {
            Import-Module ($global:path + "\OpConsole_CLI_Module.psm1") -Force
            OpConsole_CLI -srcUrl $srcUrl -destUrl $destUrl -button $button -category $category -srcUser $srcUser -srcPassword $srcPassword -destUser $destUser -destPassword $destPassword -srcToken $srcToken -destToken $destToken
        }
    }
    else
    { 
        Write-Host "Unable to import OpCon module from"$opconModule 
        Exit
    }
}
else 
{
    Write-Host "Powershell Version 7.0 or greater required!"
    Exit 1
}