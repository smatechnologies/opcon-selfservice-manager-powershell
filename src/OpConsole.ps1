<#
The purpose of this script is to provide a framework for managing OpCon in a terminal.

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
    $OpConModule = "C:\Users\bjernell\OneDrive - SMA\Bruce\Github\OpCon_API\Module\OpConModule.psm1"
)

$global:version = "1.6"

function OpConsole_Import_Logins()
{
    $global:opconLogins = [System.Collections.ArrayList]@()
    $global:opconLogins.Add( [PSCustomObject]@{
        "name"="Add New";
        "user"="";
        "externalToken"="";
        "url"="";
        "lastLogin"="";
        "expires"=""
    } ) | Out-Null

    if(Test-Path ($global:path + "\logins.json"))
    {
        $readLoginFile = Get-Content ($global:path + "\logins.json") | Out-String | ConvertFrom-Json -Depth 3
        if($readLoginFile.Count -gt 1)
        { 
            $readLoginFile | ForEach-Object{
                if(($_.name -ne "Add New") -and ($_.name))
                { $global:opconLogins.Add( $_ ) | Out-Null }
            }
        }
    }

    $global:opconLogins | ConvertTo-Json -Depth 3 -AsArray | Out-String | Out-File ($global:path + "\logins.json") -Force
}

function OpConsole_CheckExpression()
{
    $ExpressionDialog = [Terminal.Gui.Dialog]::new()
    $ExpressionDialog.Title = "Check Expressions, [Escape] to close"

    #Expression
    $ExpressionLabel = [Terminal.Gui.Label]::new()
    $ExpressionLabel.Height = 1
    $ExpressionLabel.Width = 15
    $ExpressionLabel.Text = "Expression"

    $ExpressionTextfield = [Terminal.Gui.Textfield]::new()
    $ExpressionTextfield.Width = 250
    $ExpressionTextfield.X = [Terminal.Gui.Pos]::Right($ExpressionLabel)

    $ExpressionDialog.Add($ExpressionLabel) 
    $ExpressionDialog.Add($ExpressionTextfield)

    # Submit button
    $ExpressionSubmit = [Terminal.Gui.Button]::new()
    $ExpressionSubmit.Text = "Check Expression"
    $ExpressionSubmit.add_Clicked({ 
        $validation = OpCon_PropertyExpression -url $global:activeOpCon.url -token $global:activeOpCon.externalToken -expression $ExpressionTextfield.text.ToString()

        if($validation.result -eq "true")
        { [Terminal.Gui.MessageBox]::Query("Result", "The expression was true!","OK") }
        else 
        { [Terminal.Gui.MessageBox]::Query("Result", "The expression was false!","OK") }
    })
    $ExpressionSubmit.Y = [Terminal.Gui.Pos]::Bottom($ExpressionTextfield)
    $ExpressionSubmit.X = [Terminal.Gui.Pos]::Center()
    $ExpressionDialog.Add($ExpressionSubmit)

    [Terminal.Gui.Application]::Run($ExpressionDialog)
}

function BuildStartPage($Window)
{
    $StartScreen = [Terminal.Gui.Label]::new()
    $StartScreen.Height = 20
    $StartScreen.Width = 60
    $StartScreen.Y = [Terminal.Gui.Pos]::Bottom($global:MenuBar)
    $StartScreen.X = [Terminal.Gui.Pos]::Center()
    $StartScreen.Text = "`n`n`n`n`n
                       Welcome to`n`n
      O   PPPP  CCC   O   N   N SSS    O   L    EEEE
    O   O P  P C    O   O N N N S    O   O L    E
    O   O PPPP C    O   O N  NN  SS  O   O L    EEEE
    O   O P    C    O   O N   N    S O   O L    E
      O   P     CCC   O   N   N SSS    O   LLLL EEEE"
    
    $Window.Add($StartScreen)
}

# Builds top navigation menu
function BuildMenu($Window)
{
    $MenuItemHome = [Terminal.Gui.MenuItem]::new("_Home", "", {             
        # Close the window
        $Window.RemoveAll()

        # Application
        $Window = [Terminal.Gui.Window]::new()
        $Window.Title = "OpConsole (v" + $global:version + ")"
        $Window.add_KeyPress({ param($arg) 
            if($arg.KeyEvent.Key.ToString() -eq "F2")
            { $global:MenuBar.OpenMenu() }
        })
        [Terminal.Gui.Application]::Top.Add($Window)
        
        OpConsole -Window $window
    })
    $MenuItemCheckExp = [Terminal.Gui.MenuItem]::new("_Check Expression", "", { OpConsole_CheckExpression })
    $MenuItemExit = [Terminal.Gui.MenuItem]::new("_Exit", "", { Exit })
    $MenuItemConnect = [Terminal.Gui.MenuItem]::new("_Add Login", "", { 
        OpConsole_Login
        OpConsole_Select_Environment 
    })
    $MenuItemSelectEnv = [Terminal.Gui.MenuItem]::new("_Select Environment", "", {             
        # Close the window
        $Window.RemoveAll()
        OpConsole_Select_Environment 
    } )
    $MenuItemCustom = [Terminal.Gui.MenuItem]::new("_Custom Module", "", { 
        $CustomDialog = [Terminal.Gui.OpenDialog]::new("Select Custom Module", "")
        $CustomDialog.NameFieldLabel = "Name:"
        [Terminal.Gui.Application]::Run($CustomDialog)

        # Makes sure the dialog was not closed
        if(!$CustomDialog.Canceled)
        { 
            # Imports the custom module functions
            Import-Module ( $CustomDialog.Filepath.ToString() ) -Force -Verbose
            Write-Host (Get-Date).ToString()" Imported Module"$CustomDialog.Filepath.ToString()
            
            # Starts custom module
            OpConsole_Custom_Start

            # Unloads module functions
            Remove-Module -Name ( (Split-Path $CustomDialog.Filepath.ToString() -leaf -Resolve).Replace(".psm1","") )
            Write-Host (Get-Date).ToString()" Removed Module"( (Split-Path $CustomDialog.Filepath.ToString() -leaf -Resolve).Replace(".psm1","") )
        } 
    })
    $MenuItemSelfService = [Terminal.Gui.MenuItem]::new("_Manage Self Service", "", { 
        Import-Module ($global:path + "\OpConsole_Self_Service_Module.psm1") -Force
        OpConsole_Self_Service
    } )
    $MenuItemOpConDocs = [Terminal.Gui.MenuItem]::new("_OpCon Documentation", "", { Start-Process https://help.smatechnologies.com } )
    $MenuItemOpConsole = [Terminal.Gui.MenuItem]::new("_About", "", { [Terminal.Gui.MessageBox]::Query("About OpConsole", "Version " + $version + "`nWritten by Bruce Jernell`n`nCheck the project on github:`nhttps://tinyurl.com/135bucas", @("Close")) } )
    
    $MenuBarItemNavigation = [Terminal.Gui.MenuBarItem]::new("Navigation (F2)",@($MenuItemHome,$MenuItemCheckExp,$MenuItemSelfService,$MenuItemCustom,$MenuItemExit))
    $MenuBarItemLogins = [Terminal.Gui.MenuBarItem]::new("Connection/s", @($MenuItemSelectEnv,$MenuItemConnect))
    $MenuBarItemHelp = [Terminal.Gui.MenuBarItem]::new("Help",@($MenuItemOpConsole,$MenuItemOpConDocs))

    $global:MenuBar = [Terminal.Gui.MenuBar]::new(@($MenuBarItemNavigation,$MenuBarItemLogins,$MenuBarItemHelp))
    $Window.Add($global:MenuBar)
}

function OpConsole($Window)
{
    # Builds buttons/menu for start screen
    BuildMenu -Window $Window  
    BuildStartPage -Window $Window

    [Terminal.Gui.Application]::Run()
}

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
            
            # Import Logins
            OpConsole_Import_Logins

            # Start main OpConsole program
            Import-Module ($global:path + "\OpConsole_Login_Module.psm1") -Force
            Import-Module Microsoft.PowerShell.ConsoleGuiTools -Force
            $module = (Get-Module Microsoft.PowerShell.ConsoleGuiTools -List).ModuleBase
            Add-Type -Path (Join-path $module Terminal.Gui.dll)
            [Terminal.Gui.Application]::Init()
        
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