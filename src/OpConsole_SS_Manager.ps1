<#
The purpose of this script is to move a button from one OpCon Self Service environment to another

Future releases will add the ability create new categories and transform pieces of the buttons.

v1.4 - Bug fixes, UX improvements and ability to flip environments
v1.3 - Added ability to move category of buttons
v1.2 - Bug fixes for category checks and added logging
v1.15 - Updated the menu bar and checkbox locations.
v1.1 - Added logic/options to run from a command line.  Also various bug fixes.
v1.0 - Initial release
#>
param(
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
    [Switch]$cli # Switch option so the program can be run from an OpCon job
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
    { $failed = $true;[Terminal.Gui.MessageBox]::ErrorQuery("Failed", $_.Exception.Message ) }

    if($failed)
    {
        Write-Host ("Authentication to " + $url + " as user " + $user + " failed!") 
        ("Authentication to " + $url + "as user " + $user + "failed!`n`n") | Out-File -FilePath ($global:path + "\SSmgr-" + (Get-Date -Format "MMddyyyy") + ".log") -Append
    }
    else 
    {
        Write-Host ("Authenticated to " + $url + " as user " + $user + "!`n") 
        ("Authenticated to " + $url + "as user " + $user + "!`n`n") | Out-File -FilePath ($global:path + "\SSmgr-" + (Get-Date -Format "MMddyyyy") + ".log") -Append
    }

    return $apiuser
}

function OpCon_LoginCL($url,$user,$password)
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
        Write-Host "Authenticated to $url!"
    }
    catch [Exception]
    { 
        Write-Host $_
        Exit 3    
    }

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

function OpCon_GetServiceRequestCL($url,$token,$id,$button)
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
    { 
        Write-Host $_ 
        Exit 3
    }

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
    { 
        Write-Host $_
        $_ | Out-File -FilePath ($global:path + "\SSmgr-" + (Get-Date -Format "MMddyyyy") + ".log") -Append

        [Terminal.Gui.MessageBox]::ErrorQuery("Failed Adding Button", $_.Exception.Message ) 

        # To make sure success messages are not sent
        $failed = "failed"
    }

    if($failed -ne "failed")
    { 
        Write-Host ("Button: " + $servicerequest.name + "`nAdded to " + $global:destURL + "`n`n") 
        ("Button: " + $servicerequest.name + "`nAdded to " + $global:destURL + "`n`n") | Out-File -FilePath ($global:path + "\SSmgr-" + (Get-Date -Format "MMddyyyy") + ".log") -Append
        
        [Terminal.Gui.MessageBox]::Query("Button "+ $servicerequest.name + " added to "+$url, "***Success***",@("Close") ) 
    }

    return $servicerequest
}

function OpCon_CreateServiceRequestCL($url,$token,$name,$doc,$html,$details,$disable,$hide,$category,$categoryName,$roles,$object)
{
    try 
    {
        if($object)
        { $servicerequest = Invoke-Restmethod -Method POST -Uri ($url + "/api/ServiceRequests") -Headers @{"authorization" = $token} -Body ($object | ConvertTo-Json -Depth 5) -ContentType "application/json" }
        else 
        {
            # CONVERT TO OBJECT @{...}
            if($categoryName)
            { $categoryObject = OpCon_GetServiceRequestCategoryCL -url $url -token $token -category "$category" }
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
    { 
        Write-Host $_
        Exit 3
    }

    Write-Host "Button "$servicerequest.name"added to $url"

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
            { $result = Invoke-RestMethod -Method GET -Uri ($url + "/api/ServiceRequestCategories/" + $getCategory[0].id) -Headers @{"authorization" = $token} -ContentType "application/json"  }
        }
        elseif($id)
        { $result = Invoke-RestMethod -Method GET -Uri ($url + "/api/ServiceRequestCategories/" + $id) -Headers @{"authorization" = $token} -ContentType "application/json" }
        else 
        { $result = Invoke-RestMethod -Method GET -Uri ($url + "/api/ServiceRequestCategories") -Headers @{"authorization" = $token} -ContentType "application/json" }
    }
    catch [Exception]
    { [Terminal.Gui.MessageBox]::ErrorQuery("Failed", $_.Exception.Message ) }

    return $result
}

#Function to get a Service Request category/categories
function OpCon_GetServiceRequestCategoryCL($url,$token,$category,$id)
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
    { 
        Write-Host $_  
        Exit 3
    }

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

        #Load content for environment frame
        $EnvContent.Text = "Source: " + $global:srcURL + "`nDestination: " + $global:destUrl
        $EnvButton.Visible = $true

        if(($global:srcToken -ne "Token ") -and ($global:srcToken) -and ($global:destToken -ne "Token ") -and ($global:destToken))
        {
            # Grab all categories and buttons
            $global:buttons = OpCon_GetServiceRequest -url $global:srcUrl -token $global:srcToken | Sort-Object -Property "Name"
            $global:categories = OpCon_GetServiceRequestCategory -url $global:srcUrl -token $global:srcToken | Sort-Object -Property "name"

            if($global:buttons.Count -eq 0)
            { $global:buttons = @() }
            elseif($global:buttons.Count -eq 1)
            { $global:buttons = @( $global:buttons.name ) }

            if($global:categoriess.Count -eq 0)
            { $global:categories = @() }
            elseif($global:categories.Count -eq 1)
            { $global:categories = @( $global:categories.name ) }

            # Close the dialog window
            [Terminal.Gui.Application]::RequestStop()

            #Open the Menu
            $MenuBar.OpenMenu()
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

#----------------------------------------------------------------------------------------------------------------------------------

# Verify PS version is at least 7
if($PSVersionTable.PSVersion.Major -ge 7)
{
    #Skip self signed certificates
    OpCon_SkipCerts

    #Store script path for logging purposes
    $global:path = Split-Path -parent $MyInvocation.MyCommand.Definition
}
else 
{
    Write-Host "Powershell Version 7.0 or greater required!"
    Exit 1
}

# Checks to see whether to run the command line or gui version
if($cli)
{
    if(((($srcUser -and $srcPassword) -or $srcToken) -and $srcURL) -and ((($destUser -and $destPassword) -or $destToken) -and $destURL))
    {
        if(!$srcToken)
        { $srcToken = "Token " + (OpCOn_LoginCL -url $srcURL -user $srcUser -password $srcPassword).id }

        if(!$destToken)
        { $destToken = "Token " + (OpCOn_LoginCL -url $destURL -user $destUser -password $destPassword).id }

        if($button)
        {
            # Grab button information
            $sourceButton = OpCon_GetServiceRequestCL -url $srcUrl -token $srcToken $name $button

            # Default to ocadm role in destination OpCon
            $sourceButton.roles = @(@{ "id" = 0;"name"="ocadm"})

            # Match category/ids
            if($sourceButton.servicerequestCategory)
            { 
                $getCategory = OpCon_GetServiceRequestCategoryCL -url $destURL -token $destToken -category $sourceButton.servicerequestCategory.name
                
                if($getCategory)
                { $destinationCategory = [PSCustomObject]@{ "id" = $getCategory.id;"name" = $getCategory.name; "color" = $getCategory.color } }
                
                # If Categories were matched/not
                if($destinationCategory)
                { 
                    $sourceButton.servicerequestCategory = $destinationCategory
                    $newButton = OpCon_CreateServiceRequestCL -url $destUrl -token $destToken -object $sourceButton
                }
                else 
                { $newButton = OpCon_CreateServiceRequestCL -url $destUrl -token $destToken-object ($sourceButton | Select-Object -ExcludeProperty "serviceRequestCategory") }

            }
            else
            { $newButton = OpCon_CreateServiceRequestCL -url $destUrl -token $destToken -object $sourceButton }
        }
        elseif($category)
        {
            $sourceButtons = OpCon_GetServiceRequestCL -url $srcUrl -token $srcToken | Where-Object{ $_.serviceRequestCategory.name -eq $category }
            
            # Default to ocadm role in destination OpCon
            $role = @(@{ "id" = 0;"name"="ocadm"})

            # Match category/ids
            $getCategory = OpCon_GetServiceRequestCategoryCL -url $destURL -token $destToken -category $category
        
            if($getCategory)
            { $destinationCategory = [PSCustomObject]@{ "id" = $getCategory.id;"name" = $getCategory.name; "color" = $getCategory.color } }
            
            # If Categories were matched/not
            if($destinationCategory)
            { 
                $sourceButtons | ForEach-Object{
                                                $details = OpCon_GetServiceRequestCL -url $srcUrl -token $srcToken -id $_.id
                                                $details.roles = $role
                                                $details.serviceRequestCategory = $destinationCategory
                                                OpCon_CreateServiceRequestCL -url $destUrl -token $destToken -name $details.name -object $details | Out-Null
                }
            }
            else 
            {
                $sourceButtons | ForEach-Object{
                                                $details = OpCon_GetServiceRequestCL -url $srcUrl -token $srcToken -id $_.id
                                                $details.roles = $role
                                                OpCon_CreateServiceRequestCL -url $destUrl -token $destToken -name $details.name -object ($details | Select-Object -ExcludeProperty "serviceRequestCategory") | Out-Null
                }    
            } 
        }
    }
    else 
    {
        Write-Host "Missing a user/password or token!"
        Exit 2    
    }
}
else 
{
    Import-Module Microsoft.PowerShell.ConsoleGuiTools 
    $module = (Get-Module Microsoft.PowerShell.ConsoleGuiTools -List).ModuleBase
    Add-Type -Path (Join-path $module Terminal.Gui.dll)
    [Terminal.Gui.Application]::Init()

    #Application
    $Window = [Terminal.Gui.Window]::new()
    $Window.Title = "OpConsole - Self Service Manager"
    $Window.add_KeyPress({ param($arg) 
                        if($arg.KeyEvent.Key.ToString() -eq "F2")
                        { $MenuBar.OpenMenu() }
                        })
    [Terminal.Gui.Application]::Top.Add($Window)

    #Menu
    $MenuItemConnect = [Terminal.Gui.MenuItem]::new("_Connect to OpCon", "", { BuildLoginDialog } )
    $MenuItemButtons = [Terminal.Gui.MenuItem]::new("_Buttons","", { 
                                                            if($MenuItemButtons.Checked -eq $true)
                                                            { 
                                                                # Clear checkbox
                                                                $MenuItemButtons.Checked = $false 

                                                                # Clear frames
                                                                $ListView.SetSource(@())
                                                                $Content2.Text = ""
                                                                $CatButtonListView.SetSource(@())
                                                                $CatButtonsFrame.Title = ""
                                                            }
                                                            else
                                                            { 
                                                                # Show the item as checked
                                                                $MenuItemButtons.Checked = $true
                                                                $MenuItemCategory.Checked = $false
                                                                
                                                                # Remove button for sending button
                                                                $CategoryButton.Visible = $false

                                                                # Clear any text from the right side
                                                                $Content2.Text = ""
                                                                $CatButtonListView.SetSource(@())
                                                                $CatButtonsFrame.Title = "Button Roles"

                                                                # Verify successful authentication to OpCon
                                                                if(($global:srcToken -ne "Token ") -and ($global:srcToken))
                                                                { 
                                                                    # Grab all buttons
                                                                    $global:buttons = OpCon_GetServiceRequest -url $global:srcUrl -token $global:srcToken | Sort-Object -Property "Name"

                                                                    if($global:buttons.Count -eq 0)
                                                                    {
                                                                        $global:buttons = @() 
                                                                        $ListView.SetSource( @() )  
                                                                    }
                                                                    elseif($global:buttons.Count -eq 1)
                                                                    {
                                                                        $global:buttons = @( $global:buttons ) 
                                                                        $ListView.SetSource( @( $global:buttons.name ) ) 
                                                                    }
                                                                    else 
                                                                    { $ListView.SetSource($global:buttons.name) }
                                                                }
                                                                else 
                                                                { 
                                                                    $MenuItemButtons.Checked = $false
                                                                    [Terminal.Gui.MessageBox]::ErrorQuery("Error - Not Authenticated to OpCon", "Go to Menu -> Connect to OpCon`nPress ESC to close this window") 
                                                                }  
                                                            }
                                                        } )
    $MenuItemButtons.CheckType = "Checked"
    $MenuItemCategory = [Terminal.Gui.MenuItem]::new("_Category","", { 
                                                            if($MenuItemCategory.Checked -eq $true)
                                                            {
                                                                # Clear checkbox 
                                                                $MenuItemCategory.Checked = $false 

                                                                # Clear frames
                                                                $ListView.SetSource(@())
                                                                $Content2.Text = ""
                                                                $CatButtonListView.SetSource(@())
                                                            }
                                                            else
                                                            { 
                                                                # Show the item as checked
                                                                $MenuItemCategory.Checked = $true
                                                                $MenuItemButtons.Checked = $false

                                                                # Remove button for sending button
                                                                $Button.Visible = $false

                                                                # Clear any text from the right side
                                                                $Content2.Text = ""
                                                                $CatButtonListView.SetSource(@())
                                                                $CatButtonsFrame.Title = "Buttons in Category"

                                                                # Verify successful authentication to OpCon
                                                                if(($global:srcToken -ne "Token ") -and ($global:srcToken))
                                                                { 
                                                                    #Grab all categories
                                                                    $global:categories = OpCon_GetServiceRequestCategory -url $global:srcUrl -token $global:srcToken | Sort-Object -Property "name"

                                                                    if($global:categories.Count -eq 0)
                                                                    { 
                                                                        $global:categories = @() 
                                                                        $ListView.SetSource($global:categories)
                                                                    }
                                                                    elseif($global:categories.Count -eq 1)
                                                                    { 
                                                                        $global:categories = @( $global:categories ) 
                                                                        $ListView.SetSource($global:categories.name)
                                                                    }
                                                                    else 
                                                                    { $ListView.SetSource($global:categories.name) }
                                                                }
                                                                else 
                                                                { 
                                                                    $MenuItemCategory.Checked = $false
                                                                    [Terminal.Gui.MessageBox]::ErrorQuery("Error - Not Authenticated to OpCon", "Go to Menu -> Connect to OpCon`nPress ESC to close this window") 
                                                                }
                                                            }
    } )
    $MenuItemCategory.CheckType = "Checked"
    $MenuItemOpConDocs = [Terminal.Gui.MenuItem]::new("_OpCon Documentation", "", { Start-Process https://help.smatechnologies.com } )
    $MenuItemOpConsole = [Terminal.Gui.MenuItem]::new("_About", "", { [Terminal.Gui.MessageBox]::Query("OpConsole Documentation", "Version 1.4`nWritten by Bruce Jernell`n`nCheck the project on github:`nhttps://tinyurl.com/135bucas", @("Close")) } )
    $MenuItemExit = [Terminal.Gui.MenuItem]::new("_Exit (Ctrl + Q)", "", { Exit })
    $MenuBarItemMenu = [Terminal.Gui.MenuBarItem]::new("Connection/s", @($MenuItemConnect))
    $MenuBarItemDisplay = [Terminal.Gui.MenuBarItem]::new("Display Options (F2)", @($MenuItemButtons,$MenuItemCategory))
    $MenuBarItemHelp = [Terminal.Gui.MenuBarItem]::new("Help",@($MenuItemOpConsole,$MenuItemOpConDocs,$MenuItemExit))
    $MenuBar = [Terminal.Gui.MenuBar]::new(@($MenuBarItemDisplay,$MenuBarItemMenu,$MenuBarItemHelp))
    $Window.Add($MenuBar)

    #Frame 1
    $Frame1 = [Terminal.Gui.FrameView]::new()
    $Frame1.Width = [Terminal.Gui.Dim]::Percent(35)
    $Frame1.Height = [Terminal.Gui.Dim]::Fill()
    $Frame1.Y = [Terminal.Gui.Pos]::Bottom($MenuBar)
    $Frame1.Title = "Source selection"
    $Window.Add($Frame1)

    #Frame 2
    $Frame2 = [Terminal.Gui.FrameView]::new()
    $Frame2.Width = [Terminal.Gui.Dim]::Percent(65)
    $Frame2.Height = [Terminal.Gui.Dim]::Percent(65)
    $Frame2.X = [Terminal.Gui.Pos]::Right($Frame1)
    $Frame2.Y = [Terminal.Gui.Pos]::Bottom($MenuBar)
    $Frame2.Title = "Details"
    $Window.Add($Frame2)

    #Category buttons list frame
    $CatButtonsFrame = [Terminal.Gui.Frameview]::new()
    $CatButtonsFrame.Width = [Terminal.Gui.Dim]::Percent(65)
    $CatButtonsFrame.Height = [Terminal.Gui.Dim]::Percent(15)
    $CatButtonsFrame.Y = [Terminal.Gui.Pos]::Bottom($Frame2)
    $CatButtonsFrame.X = [Terminal.Gui.Pos]::Right($Frame1)
    $CatButtonsFrame.Title = "Additional Information"
    $Window.Add($CatButtonsFrame)

    #Environment
    $EnvFrame = [Terminal.Gui.FrameView]::new()
    $EnvFrame.Width = [Terminal.Gui.Dim]::Percent(65)
    $EnvFrame.Height = [Terminal.Gui.Dim]::Percent(20)
    $EnvFrame.X = [Terminal.Gui.Pos]::Right($Frame1)
    $EnvFrame.Y = [Terminal.Gui.Pos]::Bottom($CatButtonsFrame)
    $EnvFrame.Title = "Environments"
    $Window.Add($EnvFrame)

    #Frame 1 content
    $ListView = [Terminal.Gui.ListView]::new()
    $ListView.Width = [Terminal.Gui.Dim]::Fill()
    $ListView.Height = [Terminal.Gui.Dim]::Fill()
    $ListView.add_SelectedItemChanged( { 
        if($MenuItemButtons.Checked -eq $true)
        {
            if(($global:srcToken -ne "Token ") -and ($global:srcToken))
            {
                if(($global:buttons[$ListView.SelectedItem].documentation).Length -gt 200)
                { $buttonDocs = ($global:buttons[$ListView.SelectedItem].documentation).SubString(0,200) }
                else 
                { $buttonDocs = $global:buttons[$ListView.SelectedItem].documentation }

                if(($global:buttons[$ListView.SelectedItem].html).Length -gt 200)
                { $buttonHTML = ($global:buttons[$ListView.SelectedItem].html).SubString(0,200) }
                else 
                { $buttonHTML = $global:buttons[$ListView.SelectedItem].html }

                $Content2.Text = "NAME: " + $global:buttons[$ListView.SelectedItem].name + 
                                "`n`nDOCUMENTATION: " + $buttonDocs +
                                "`n`nCATEGORY: " + $global:buttons[$ListView.SelectedItem].serviceRequestCategory.name + 
                                "`n`nHTML: " + $buttonHTML
                
                $buttonSpecific = OpCon_GetServiceRequest -url $global:srcUrl -token $global:srcToken -id $global:buttons[$ListView.SelectedItem].id
                if($buttonSpecific.roles.Count -eq 0)
                { $CatButtonListView.SetSource( @() ) }
                elseif($buttonSpecific.roles.Count -eq 1)
                { $CatButtonListView.SetSource( @($buttonSpecific.roles.name) ) }
                else
                { $CatButtonListView.SetSource( ($buttonSpecific.roles.name | Sort-Object) ) }            

                # Only add the button if buttons have been received
                $Button.Visible = $true
                $CategoryButton.Visible = $false
            }
            else 
            { 
                $MenuItemButton.Checked = $false
                [Terminal.Gui.MessageBox]::ErrorQuery("Error - Not Authenticated to OpCon", "Go to Menu -> Connect to OpCon`nPress ESC to close this window") 
            }
        }
        elseif($MenuItemCategory.Checked -eq $true)
        {
            if(($global:srcToken -ne "Token ") -and ($global:srcToken))
            {
                $buttonsByCategory = ($global:buttons).Where({ $_.serviceRequestCategory.name -Match $global:categories[$ListView.SelectedItem].name })

                $Content2.Text = "CATEGORY: " + $global:categories[$ListView.SelectedItem].name + 
                                "`n`nCOLOR: " + $global:categories[$ListView.SelectedItem].color

                if($buttonsByCategory.Count -eq 0)
                { $CatButtonListView.SetSource( @() ) }
                elseif($buttonsByCategory.Count -eq 1)
                { $CatButtonListView.SetSource( @($buttonsByCategory[0].name) ) }
                else
                { $CatButtonListView.SetSource( ($buttonsByCategory.name | Sort-Object) ) }

                # Only add the button if buttons have been received
                $CategoryButton.Visible = $true
                $Button.Visible = $false
            }
            else 
            { 
                $MenuItemCategory.Checked = $false
                [Terminal.Gui.MessageBox]::ErrorQuery("Error - Not Authenticated to OpCon", "Go to Menu -> Connect to OpCon`nPress ESC to close this window") 
            }
        }
    } )
    $Frame1.Add($ListView)

    #Frame 2 content
    $Content2 = [Terminal.Gui.Label]::new()
    $Content2.Height = [Terminal.Gui.Dim]::Percent(95)
    $Content2.Width = [Terminal.Gui.Dim]::Fill()
    $Frame2.Add($Content2)

    #Env content
    $EnvContent = [Terminal.Gui.Label]::new()
    $EnvContent.Text = "SOURCE: " + $global:srcURL + "`nDESTINATION: " + $global:destUrl
    $EnvContent.Height = [Terminal.Gui.Dim]::Percent(75)
    $EnvContent.Width = [Terminal.Gui.Dim]::Fill()
    $EnvFrame.Add($EnvContent)

    #region Category Button
    $CategoryButton = [Terminal.Gui.Button]::new()
    $CategoryButton.Text = "SUBMIT CATEGORY"
    $CategoryButton.add_Clicked({ 
        $confirmSubmission = [Terminal.Gui.MessageBox]::Query("Confirm submission", "**All buttons in the category will be copied**`n`n**Role/s will be set to 'ocadm'**`n`n**Category will be matched or set to none**", @("Submit","Cancel")) 

        # Make sure user hits OK before making change
        if($confirmSubmission -eq 0)
        { 
            $sourceButtons = $global:buttons | Where-Object{ $_.serviceRequestCategory.name -eq $global:categories[$ListView.selectedItem].name }
            
            # Default to ocadm role in destination OpCon
            $role = @(@{ "id" = 0;"name"="ocadm"})

            # Match category/ids
            $getCategory = OpCon_GetServiceRequestCategory -url $global:destURL -token $global:destToken -category $global:categories[$ListView.selectedItem].name
        
            if($getCategory)
            { $destinationCategory = [PSCustomObject]@{ "id" = $getCategory.id;"name" = $getCategory.name; "color" = $getCategory.color } }
            
            # If Categories were matched/not
            if($destinationCategory)
            { 
                $sourceButtons | ForEach-Object{
                                                $details = OpCon_GetServiceRequest -url $global:srcUrl -token $global:srcToken -id $_.id
                                                $details.roles = $role
                                                $details.serviceRequestCategory = $destinationCategory
                                                OpCon_CreateServiceRequest -url $global:destUrl -token $global:destToken -name $details.name -object $details | Out-Null
                }
            }
            else 
            {
                $sourceButtons | ForEach-Object{
                                                $details = OpCon_GetServiceRequest -url $global:srcUrl -token $global:srcToken -id $_.id
                                                $details.roles = $role
                                                OpCon_CreateServiceRequest -url $global:destUrl -token $global:destToken -name $details.name -object ($details | Select-Object -ExcludeProperty "serviceRequestCategory") | Out-Null
                }    
            } 
        }
    })
    $CategoryButton.Y = [Terminal.Gui.Pos]::Bottom($Content2)
    $CategoryButton.X = [Terminal.Gui.Pos]::Center()
    $CategoryButton.Visible = $false
    $Frame2.Add($CategoryButton)
    #endregion

    #Send buttons
    $Button = [Terminal.Gui.Button]::new()
    $Button.Text = ("SUBMIT BUTTON")
    $Button.add_Clicked({ 
        $confirmSubmission = [Terminal.Gui.MessageBox]::Query("Confirm submission", "**Role/s will be set to 'ocadm'**`n`n**Category matched or set to none**", @("Submit","Cancel")) 

        # Make sure user hits OK before making change
        if($confirmSubmission -eq 0)
        { 
            $sourceButton = OpCon_GetServiceRequest -url $global:srcUrl -token $global:srcToken -id $global:buttons[$ListView.SelectedItem].id

            # Default to ocadm role in destination OpCon
            $sourceButton.roles = @(@{ "id" = 0;"name"="ocadm"})

            # Match category/ids
            if($sourceButton.servicerequestCategory)
            { 
                $getCategory = OpCon_GetServiceRequestCategory -url $global:destURL -token $global:destToken -category $sourceButton.servicerequestCategory.name
            
                if($getCategory)
                { $destinationCategory = [PSCustomObject]@{ "id" = $getCategory.id;"name" = $getCategory.name; "color" = $getCategory.color } }
                
                # If Categories were matched/not
                if($destinationCategory)
                { 
                    $sourceButton.serviceRequestCategory = $destinationCategory
                    $newButton = OpCon_CreateServiceRequest -url $global:destUrl -token $global:destToken -object $sourceButton
                }
                else 
                { $newButton = OpCon_CreateServiceRequest -url $global:destUrl -token $global:destToken -object ($sourceButton | Select-Object -ExcludeProperty "serviceRequestCategory") }

            }
            else
            { $newButton = OpCon_CreateServiceRequest -url $global:destUrl -token $global:destToken -object $sourceButton }
        }
    })
    $Button.Y = [Terminal.Gui.Pos]::Bottom($Content2)
    $Button.X = [Terminal.Gui.Pos]::Center()
    $Button.Visible = $false
    $Frame2.Add($Button)

    #Category buttons list content
    $CatButtonListView = [Terminal.Gui.ListView]::new()
    $CatButtonListView.Width = [Terminal.Gui.Dim]::Fill()
    $CatButtonListView.Height = [Terminal.Gui.Dim]::Fill()
    #$CatButtonListView.add_SelectedItemChanged( { } )  #Options may be added in the future
    $CatButtonsFrame.Add($CatButtonListView)

    #region Environment Button
    $EnvButton = [Terminal.Gui.Button]::new()
    $EnvButton.Text = "FLIP ENVIRONMENTS"
    $EnvButton.add_Clicked({ 
                $tempsrcUrl = $global:srcUrl
                $tempsrcToken = $global:srcToken

                $global:srcUrl = $global:destUrl
                $global:srcToken = $global:destToken

                $global:destUrl = $tempsrcUrl
                $global:destToken = $tempsrcToken

                $EnvContent.Text = "Source: " + $global:srcURL + "`nDestination: " + $global:destUrl
                $ListView.SetSource(@())
                $Content2.Text = ""
                $CatButtonListView.SetSource(@())
    })
    $EnvButton.Y = [Terminal.Gui.Pos]::Bottom($EnvContent)
    $EnvButton.X = [Terminal.Gui.Pos]::Center()
    $EnvButton.Visible = $false
    $EnvFrame.Add($EnvButton)
    #endregion

    BuildLoginDialog
    [Terminal.Gui.Application]::Run()
}