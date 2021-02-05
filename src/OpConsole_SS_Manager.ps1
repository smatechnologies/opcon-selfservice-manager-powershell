<#
The purpose of this script is to move a button from one OpCon Self Service environment to another

Future releases will add an option to run from a command line (so it could be run inside OpCon)
as well as the ability to move all the buttons in a category as well as create new categories.

v1.0
#>
param(
    $srcUrl, # URL to Source OpCon API ie https://<opconserver>:<port>
    $destUrl, # URL to Destination OpCon API
    $button, # Button name
    $srcUser, # Used for API authentication
    $srcPassword, # Used for API authentication, recommend passing in as an encrypted global property
    $destUser, # Used for API authentication
    $destPassword, # Used for API authentication, recommend passing in as an encrypted global property
    $srcToken, # Used to specify an existing API token
    $destToken, # Used to specify an existing API token
    [Switch]$commandline # Switch option so the program can be run from an OpCon job
)

#Get user/app token
function OpCon_Login($url,$user,$password)
{
    #Build body
    $body = @{"user" = @{"loginName" = $user;
                         "password" = $password;
                        };
              "tokentype" = @{"type" = "User"}
             }

    try
    { 
        $apiuser = Invoke-Restmethod -Method POST -Uri ($url + "/api/tokens") -Body ($body | ConvertTo-Json -Depth 7) -ContentType "application/json"  
        [Terminal.Gui.MessageBox]::Query("Success", "Authenticated to $url!", @("Close"))
    }
    catch [Exception]
    { [Terminal.Gui.MessageBox]::ErrorQuery("Failed", $_.Exception.Message ) }

    return $apiuser
}


#Gets information about a Self Service button
function OpCon_GetServiceRequest($url,$token,$id,$button)
{
    try 
    {
        if($id)
        {  $getbutton = Invoke-RestMethod -Method GET -Uri ($url + "/api/ServiceRequests/" + $id) -Headers @{"authorization" = $token} -ContentType "application/json" }
        elseif($button)
        {
            $buttonDetails = Invoke-RestMethod -Method GET -Uri ($url + "/api/ServiceRequests?name=" + $button) -Headers @{"authorization" = $token} -ContentType "application/json"

            if($buttonDetails -ne "")
            { $getbutton = Invoke-RestMethod -Method GET -Uri ($url + "/api/ServiceRequests/" + $buttonDetails[0].id) -Headers @{"authorization" = $token} -ContentType "application/json" }
            else { Write-Host "No button found with name $button"}
        }
        else { $getbutton = Invoke-RestMethod -Method GET -Uri ($url + "/api/ServiceRequests") -Headers @{"authorization" = $token} -ContentType "application/json" }
    }
    catch [Exception]
    { [Terminal.Gui.MessageBox]::ErrorQuery("Failed", $_.Exception.Message ) }

    return $getbutton
}

# Creates a Service Request
# You can pass in a button $object if you use the "$object" parameter
# otherwise pass in all the parameters
function OpCon_CreateServiceRequest($url,$token,$name,$doc,$html,$details,$disable,$hide,$category,$categoryName,$roles,$object)
{
    try 
    {
        if($object)
        { $servicerequest = Invoke-Restmethod -Method POST -Uri ($url + "/api/ServiceRequests") -Headers @{"authorization" = $token} -Body ($object | ConvertTo-Json -Depth 5) -ContentType "application/json" }
        else 
        {
            # CONVERT TO OBJECT @{...}
            if($categoryName)
            { $categoryObject = OpCon_GetServiceRequestCategory -url $url -token $token -category "$category" }
            elseif($category)
            { $categoryObject = $category }

            #Build Service Request object
            $body = @{
                    "name" = $name;
                    "documentation" = $doc;
                    "details" = $details;
                    "disableRule" = $disable;
                    "hideRule" = $hide;
                    "serviceRequestCategory" = $categoryObject;
                    "roles" = @($roles) # This is an array of role objects @{id,name} I have a function for getting roles if needed
                    }
            $servicerequest = Invoke-Restmethod -Method POST -Uri ($url + "/api/ServiceRequests") -Headers @{"authorization" = $token} -Body ($body | ConvertTo-Json -Depth 5) -ContentType "application/json"
        }
    }
    catch [Exception]
    { $object | ConvertTo-Json -Depth 5 | Out-Host;[Terminal.Gui.MessageBox]::ErrorQuery("Failed", $_.Exception.Message ) }

    [Terminal.Gui.MessageBox]::Query("Button added to "+$url, "***Success***",@("Close") )

    return $servicerequest
}

#Function to get a Service Request category/categories
function OpCon_GetServiceRequestCategory($url,$token,$category,$id)
{  
    try
    {
        if($category)
        { 
            $getCategory = Invoke-RestMethod -Method GET -Uri ($url + "/api/ServiceRequestCategories?name=" + $category) -Headers @{"authorization" = $token} -ContentType "application/json" 

            if($getCategory -ne "")
            { $categories = Invoke-RestMethod -Method GET -Uri ($url + "/api/ServiceRequestCategories/" + $getCategory[0].id) -Headers @{"authorization" = $token} -ContentType "application/json"  }
            else 
            { Write-Host "Category $category not found" }
        }
        elseif($id)
        { $categories = Invoke-RestMethod -Method GET -Uri ($url + "/api/ServiceRequestCategories/" + $id) -Headers @{"authorization" = $token} -ContentType "application/json" }
        else 
        { $categories = Invoke-RestMethod -Method GET -Uri ($url + "/api/ServiceRequestCategories") -Headers @{"authorization" = $token} -ContentType "application/json" }
    }
    catch [Exception]
    { [Terminal.Gui.MessageBox]::ErrorQuery("Failed", $_.Exception.Message ) }

    return $categories
}

#Skips self signed certificates for OpCon API default setup
function OpCon_SkipCerts
{
    try
    { $PSDefaultParameterValues.Add("Invoke-RestMethod:SkipCertificateCheck",$true) }
    catch
    { $null }
}

#region Login and prompts

# Login Dialog
function BuildLoginDialog()
{
    $LoginDialog = [Terminal.Gui.Dialog]::new()
    $LoginDialog.Title = "Authenticate to OpCon APIs"

    # Source Username
    $SourceUsernameLabel = [Terminal.Gui.Label]::new()
    $SourceUsernameLabel.Height = 1
    $SourceUsernameLabel.Width = 45
    $SourceUsernameLabel.Text = "Source Username"

    $SourceUsernameTextfield = [Terminal.Gui.Textfield]::new()
    $SourceUsernameTextfield.Width = 40
    $SourceUsernameTextfield.X = [Terminal.Gui.Pos]::Right($SourceUsernameLabel)
    $LoginDialog.Add($SourceUsernameLabel) 
    $LoginDialog.Add($SourceUsernameTextfield)

    # Source Password
    $SourcePasswordLabel = [Terminal.Gui.Label]::new()
    $SourcePasswordLabel.Height = 1
    $SourcePasswordLabel.Width = 45
    $SourcePasswordLabel.Text = "Source Password"
    $SourcePasswordLabel.Y = [Terminal.Gui.Pos]::Bottom($SourceUsernameLabel)

    $SourcePasswordTextfield = [Terminal.Gui.Textfield]::new()
    $SourcePasswordTextfield.Width = 40
    $SourcePasswordTextfield.Secret = $true
    $SourcePasswordTextfield.X = [Terminal.Gui.Pos]::Right($SourcePasswordLabel)
    $SourcePasswordTextfield.Y = [Terminal.Gui.Pos]::Bottom($SourceUsernameTextfield)

    $LoginDialog.Add($SourcePasswordLabel) 
    $LoginDialog.Add($SourcePasswordTextfield)

    # Source URL
    $SourceURLLabel = [Terminal.Gui.Label]::new()
    $SourceURLLabel.Height = 1
    $SourceURLLabel.Width = 45
    $SourceURLLabel.Text = "Source URL (https://<server>:<port>)"
    $SourceURLLabel.Y = [Terminal.Gui.Pos]::Bottom($SourcePasswordLabel)
 
    $SourceURLTextfield = [Terminal.Gui.Textfield]::new()
    $SourceURLTextfield.Width = 40
    $SourceURLTextfield.X = [Terminal.Gui.Pos]::Right($SourceURLLabel)
    $SourceURLTextfield.Y = [Terminal.Gui.Pos]::Bottom($SourcePasswordTextfield)

    $LoginDialog.Add($SourceURLLabel)
    $LoginDialog.Add($SourceURLTextfield)

    # Destination Username
    $DestinationUsernameLabel = [Terminal.Gui.Label]::new()
    $DestinationUsernameLabel.Height = 1
    $DestinationUsernameLabel.Width = 45
    $DestinationUsernameLabel.Text = "Destination Username (blank for same)"
    $DestinationUsernameLabel.Y = [Terminal.Gui.Pos]::Bottom($SourceURLLabel)

    $DestinationUsernameTextfield = [Terminal.Gui.Textfield]::new()
    $DestinationUsernameTextfield.Width = 40
    $DestinationUsernameTextfield.X = [Terminal.Gui.Pos]::Right($DestinationUsernameLabel)
    $DestinationUsernameTextfield.Y = [Terminal.Gui.Pos]::Bottom($SourceURLTextfield)

    $LoginDialog.Add($DestinationUsernameLabel)
    $LoginDialog.Add($DestinationUsernameTextfield)

    # Destination Password
    $DestinationPasswordLabel = [Terminal.Gui.Label]::new()
    $DestinationPasswordLabel.Height = 1
    $DestinationPasswordLabel.Width = 45
    $DestinationPasswordLabel.Text = "Destination Password (blank for same)"
    $DestinationPasswordLabel.Y = [Terminal.Gui.Pos]::Bottom($DestinationUsernameLabel)

    $DestinationPasswordTextfield = [Terminal.Gui.Textfield]::new()
    $DestinationPasswordTextfield.Width = 40
    $DestinationPasswordTextfield.Secret = $true
    $DestinationPasswordTextfield.X = [Terminal.Gui.Pos]::Right($DestinationPasswordLabel)
    $DestinationPasswordTextfield.Y = [Terminal.Gui.Pos]::Bottom($DestinationUsernameTextfield)

    $LoginDialog.Add($DestinationPasswordLabel) 
    $LoginDialog.Add($DestinationPasswordTextfield)

    # Destination URL
    $DestinationURLLabel = [Terminal.Gui.Label]::new()
    $DestinationURLLabel.Height = 1
    $DestinationURLLabel.Width = 45
    $DestinationURLLabel.Text = "Destination URL (https://<server>:<port>)"
    $DestinationURLLabel.Y = [Terminal.Gui.Pos]::Bottom($DestinationPasswordLabel)

    $DestinationURLTextfield = [Terminal.Gui.Textfield]::new()
    $DestinationURLTextfield.Width = 40
    $DestinationURLTextfield.X = [Terminal.Gui.Pos]::Right($DestinationURLLabel)
    $DestinationURLTextfield.Y = [Terminal.Gui.Pos]::Bottom($DestinationPasswordTextfield)

    $LoginDialog.Add($DestinationURLLabel) 
    $LoginDialog.Add($DestinationURLTextfield)

    # Submit button
    $LoginSubmit = [Terminal.Gui.Button]::new()
    $LoginSubmit.Text = "Submit"
    $LoginSubmit.add_Clicked({ 
        $global:srcToken = "Token " + (OpCon_Login -url $SourceURLTextfield.text.ToString() -user $SourceUsernameTextfield.text.ToString() -password $SourcePasswordTextfield.text.ToString()).id
        $global:srcURL = $SourceURLTextfield.text.ToString()

        # Allows for using the same logins to different OpCon environments
        if($DestinationUsernameTextfield.text.ToString() -eq "")
        { $DestinationUsernameTextfield.text = $SourceUsernameTextfield.text }
        if($DestinationPasswordTextfield.text.ToString() -eq "")
        { $DestinationPasswordTextfield.text = $SourcePasswordTextfield.text }

        $global:destToken = "Token " + (OpCon_Login -url $DestinationURLTextfield.text.ToString() -user $DestinationUsernameTextfield.text.ToString() -password $DestinationPasswordTextfield.text.ToString()).id
        $global:destURL = $DestinationURLTextfield.text.ToString()

        if(($global:srcToken -ne "Token ") -and ($global:srcToken) -and ($global:destToken -ne "Token ") -and ($global:destToken))
        {
            # Grab all categories and buttons
            $global:buttons = OpCon_GetServiceRequest -url $global:srcUrl -token $global:srcToken | Sort-Object -Property "Name"
            $global:categories = OpCon_GetServiceRequestCategory -url $global:srcUrl -token $global:srcToken | Sort-Object -Property "name"

            # Close the dialog window
            [Terminal.Gui.Application]::RequestStop()
        }
        else 
        { [Terminal.Gui.MessageBox]::ErrorQuery("Error - Not Authenticated to OpCon", "Go to Menu -> Connect to OpCon`nPress ESC to close this window") }
    })
    $LoginSubmit.Y = [Terminal.Gui.Pos]::Bottom($DestinationURLTextfield)
    $LoginSubmit.X = [Terminal.Gui.Pos]::Center()
    $LoginDialog.Add($LoginSubmit)

    [Terminal.Gui.Application]::Run($LoginDialog)
}
#endregion

#  $srcButton.roles = @(@{"id" = 5;"name" = "API Test"}) 

Import-Module Microsoft.PowerShell.ConsoleGuiTools 
$module = (Get-Module Microsoft.PowerShell.ConsoleGuiTools -List).ModuleBase
Add-Type -Path (Join-path $module Terminal.Gui.dll)
[Terminal.Gui.Application]::Init()

#Skip self signed certificates
OpCon_SkipCerts

#Setup button array (for category button moves)
#$moveButtonsArray = @()

#Application
$Window = [Terminal.Gui.Window]::new()
$Window.Title = "OpConsole - Self Service Manager"
$global:showHelp = 1
$Window.add_KeyPress({ param($arg) 
                       if($arg.KeyEvent.Key.ToString() -eq "F1")
                       { 
                           if($global:showHelp -eq 1)
                           {
                               $global:showHelp = 0
                               Start-Process https://help.smatechnologies.com
                           }
                           else{ $global:showHelp = 1 }
                       }
                       elseif($arg.KeyEvent.Key.ToString() -eq "F2")
                       { $MenuBar.OpenMenu() }
                    })
[Terminal.Gui.Application]::Top.Add($Window)

#Menu
$MenuItemConnect = [Terminal.Gui.MenuItem]::new("_Connect to OpCon", "", { BuildLoginDialog } )
$MenuItemOpConDocs = [Terminal.Gui.MenuItem]::new("_OpCon Documentation (F1)", "", { Start-Process https://help.smatechnologies.com } )
$MenuItemOpConsole = [Terminal.Gui.MenuItem]::new("_About", "", { [Terminal.Gui.MessageBox]::Query("OpConsole Documentation", "Version 1.0`nWritten by Bruce Jernell`n`nCheck the project on github:`nhttps://tinyurl.com/135bucas", @("Close")) } )
$MenuItemExit = [Terminal.Gui.MenuItem]::new("_Exit (Ctrl + Q)", "", { Exit })
$MenuBarItemMenu = [Terminal.Gui.MenuBarItem]::new("Menu (F2)", @($MenuItemConnect,$MenuItemExit))
$MenuBarItemHelp = [Terminal.Gui.MenuBarItem]::new("Help",@($MenuItemOpConsole,$MenuItemOpConDocs))
$MenuBar = [Terminal.Gui.MenuBar]::new(@($MenuBarItemMenu,$MenuBarItemHelp))
$Window.Add($MenuBar)

#Frame 1
$Frame1 = [Terminal.Gui.FrameView]::new()
$Frame1.Width = [Terminal.Gui.Dim]::Percent(35)
$Frame1.Height = [Terminal.Gui.Dim]::Percent(90)
$Frame1.Y = [Terminal.Gui.Pos]::Bottom($MenuBar)
$Frame1.Title = "Source selection"
$Window.Add($Frame1)

#Frame 2
$Frame2 = [Terminal.Gui.FrameView]::new()
$Frame2.Width = [Terminal.Gui.Dim]::Percent(65)
$Frame2.Height = [Terminal.Gui.Dim]::Percent(90)
$Frame2.X = [Terminal.Gui.Pos]::Right($Frame1)
$Frame2.Y = [Terminal.Gui.Pos]::Bottom($MenuBar)
$Frame2.Title = "Additional information"
$Window.Add($Frame2)

#Frame 1 content
$ListView = [Terminal.Gui.ListView]::new()
$ListView.Width = [Terminal.Gui.Dim]::Fill()
$ListView.Height = [Terminal.Gui.Dim]::Fill()
$ListView.add_SelectedItemChanged( { 
    if($Checkbox.checked -eq $true)
    {
        if(($global:srcToken -ne "Token ") -and ($global:srcToken))
        {
            #$global:selectedButton = OpCon_GetServiceRequest -url $global:srcUrl -token $global:srcToken -id ($global:buttons[$ListView.SelectedItem].id)
            #$roles = ""
            #$global:selectedButton.roles | ForEach-Object{ $roles = $roles + $_.name + ", " }
            #$global:buttons[$ListView.SelectedItem].roles | ForEach-Object{ $roles = $roles + $_.name + ", " }

            if(($global:buttons[$ListView.SelectedItem].html).Length -gt 200)
            { $buttonHTML = ($global:buttons[$ListView.SelectedItem].html).SubString(0,200) }
            else 
            { $buttonHTML = $global:buttons[$ListView.SelectedItem].html }

            $Content2.Text = "Name: " + $global:buttons[$ListView.SelectedItem].name + 
                        "`n`nDocumentation: " + $global:buttons[$ListView.SelectedItem].documentation +
                        "`n`nHTML: " + $buttonHTML +
                        "`n`nCategory: " + $global:buttons[$ListView.SelectedItem].serviceRequestCategory.name #+ 
                        #"`n`nRoles: " + $roles.TrimEnd(", ")

            # Only add the button if buttons have been received
            $Button.Visible = $true
        }
        else 
        { 
            $Checkbox.Checked = $false
            [Terminal.Gui.MessageBox]::ErrorQuery("Error - Not Authenticated to OpCon", "Go to Menu -> Connect to OpCon`nPress ESC to close this window") 
        }

    }
    elseif($Checkbox2.checked -eq $true)
    {
        if(($global:srcToken -ne "Token ") -and ($global:srcToken))
        {
            $buttonsByCategory = ($global:buttons).Where({ $_.serviceRequestCategory.name -Match $global:categories[$ListView.SelectedItem].name })
            $catButtons = ""
            $buttonsByCategory | ForEach-Object{ $catButtons = $catButtons + $_.name + ", " }
            $Content2.Text = "Category: " + $global:categories[$ListView.SelectedItem].name + 
                             "`n`nCategory Color: " + $global:categories[$ListView.SelectedItem].color +
                             "`n`nButtons: " + $catButtons.TrimEnd(", ")
        }
        else 
        { 
            $Checkbox2.Checked = $false
            [Terminal.Gui.MessageBox]::ErrorQuery("Error - Not Authenticated to OpCon", "Go to Menu -> Connect to OpCon`nPress ESC to close this window") 
        }
        # Only add the button if buttons have been received
        #$CategoryButton.Visible = $true
    }
} )
$Frame1.Add($ListView)

#Frame 2 content
$Content2 = [Terminal.Gui.Label]::new()
$Content2.Height = [Terminal.Gui.Dim]::Percent(90)
$Content2.Width = [Terminal.Gui.Dim]::Fill()
$Frame2.Add($Content2)

#region release2
# Release 2!!
$CategoryButton = [Terminal.Gui.Button]::new()
$CategoryButton.Text = "Copy selected category buttons"
$CategoryButton.add_Clicked({ 
    #$global:selectedButton.name = "111NewButton"
    OpCon_CreateServiceRequest -url $destUrl -token $destToken -name $global:button[$ListView.SelectedItem].name -object $global:selectedButton | Out-Null
    #$global:buttons = OpCon_GetServiceRequest -url $srcUrl -token $srcToken | Sort-Object -Property "Name"
    $ListView.SetSource($global:buttons.name) 
 })
$CategoryButton.Y = [Terminal.Gui.Pos]::Bottom($Content2)
#endregion

#Send buttons
$Button = [Terminal.Gui.Button]::new()
$Button.Text = ("SEND BUTTON")
$Button.add_Clicked({ 
    $confirmSubmission = [Terminal.Gui.MessageBox]::Query("Confirm submission", "**Role/s set to 'ocadm'**`n`n**Categories matched or set to none if they don't exist**", @("Submit","Cancel")) 

    # Make sure user hits OK before making change
    if($confirmSubmission -eq 0)
    { 
        $sourceButton = OpCon_GetServiceRequest -url $global:srcUrl -token $global:srcToken -id $global:buttons[$ListView.SelectedItem].id

        # Default to ocadm role in destination OpCon
        $sourceButton.roles = @(@{ "id" = 0;"name"="ocadm"})

        # Match category/ids
        if($sourceButton.servicerequestCategory)
        { 
            $destinationCategories = @()
            $sourceButton.servicerequestCategory | ForEach-Object{ 
                                                                    $categoryName = $_.name
                                                                    $getCategory = $global:categories | Where-Object{ $_.name -eq $categoryName }
                                                                    
                                                                    if($getCategory.Count -eq 1)
                                                                    { $destinationCategories += [PSCustomObject]@{ "id" = $getCategory.id;"name" = $getCategory.name } }
                                                                } 
            
            # If Categories were matched/not
            if($destinationCategories.Count -gt 0)
            { 
                $sourceButton.servicerequestCategory = $destinationCategories 
                $newButton = OpCon_CreateServiceRequest -url $global:destUrl -token $global:destToken -name $sourceButton.name -object $sourceButton
            }
            else 
            { $newButton = OpCon_CreateServiceRequest -url $global:destUrl -token $global:destToken -name $sourceButton.name -object ($sourceButton | Select-Object -ExcludeProperty "serviceRequestCategory") }

        }
        else
        { $newButton = OpCon_CreateServiceRequest -url $global:destUrl -token $global:destToken -name $sourceButton.name -object $sourceButton }
    }
 })
$Button.Y = [Terminal.Gui.Pos]::Bottom($Content2)
$Button.X = [Terminal.Gui.Pos]::Center()
$Button.Visible = $false
$Window.Add($Button)

#region Options for copying by buttons or by category of buttons
# Options label
$OptionsLabel = [Terminal.Gui.Label]::new()
$OptionsLabel.Text = "Use the mouse or spacebar to show Buttons or Categories"
$OptionsLabel.Height = 1
$OptionsLabel.Width = 75
$OptionsLabel.Y = [Terminal.Gui.Pos]::Bottom($Frame1)
$Window.Add($OptionsLabel)

#Button Option Label
$Label = [Terminal.Gui.Label]::new()
$Label.Text = "Buttons"
$Label.Height = 1
$Label.Width = 15
$Label.Y = [Terminal.Gui.Pos]::Bottom($OptionsLabel)
$Window.Add($Label)

#Button Option Checkbox
$Checkbox = [Terminal.Gui.Checkbox]::new()
$Checkbox.Checked = $false
$Checkbox.add_Toggled({ 
                        if($Checkbox.Checked -eq $true)
                        {
                            # Uncheck category checkbox
                            $Checkbox2.Checked = $false

                            # Clear any text from the right side
                            $Content2.Text = ""

                            # Remove button for sending category of buttons
                            #$CategoryButton.Visible = $false

                            # Grab and populate frames
                            if(($global:srcToken -ne "Token ") -and ($global:srcToken))
                            { $ListView.SetSource($global:buttons.name) }
                            else 
                            { 
                                $Checkbox.Checked = $false
                                [Terminal.Gui.MessageBox]::ErrorQuery("Error - Not Authenticated to OpCon", "Go to Menu -> Connect to OpCon`nPress ESC to close this window")
                            }
                        }
                    })
$Checkbox.Y = [Terminal.Gui.Pos]::Bottom($OptionsLabel)
$Checkbox.X = [Terminal.Gui.Pos]::Right($Label)
$Window.Add($Checkbox)

#Category Option Label
$Label2 = [Terminal.Gui.Label]::new()
$Label2.Text = "Categories"
$Label2.Height = 1
$Label2.Width = 15
$Label2.Y = [Terminal.Gui.Pos]::Bottom($OptionsLabel)
$Label2.X = [Terminal.Gui.Pos]::Right($Checkbox)
$Window.Add($Label2)

#Category Option Checkbox
$Checkbox2 = [Terminal.Gui.Checkbox]::new()
$Checkbox2.Checked = $false
$Checkbox2.add_Toggled({ 
            if($Checkbox2.Checked -eq $true)
            {
                # Uncheck buttons checkbox
                $Checkbox.Checked = $false

                # Remove button for sending button
                $Button.Visible = $false

                # Clear any text from the right side
                $Content2.Text = ""

                # Verify successful authentication to OpCon
                if(($global:srcToken -ne "Token ") -and ($global:srcToken))
                { $ListView.SetSource($global:categories.name) }
                else 
                { 
                    $Checkbox2.Checked = $false
                    [Terminal.Gui.MessageBox]::ErrorQuery("Error - Not Authenticated to OpCon", "Go to Menu -> Connect to OpCon`nPress ESC to close this window") 
                }
            }
})
$Checkbox2.Y = [Terminal.Gui.Pos]::Bottom($OptionsLabel)
$Checkbox2.X = [Terminal.Gui.Pos]::Right($Label2)
$Window.Add($Checkbox2)
#endregion

[Terminal.Gui.Application]::Run()