# Login Dialog
function OpConsole_Login()
{
    $LoginDialog = [Terminal.Gui.Dialog]::new()
    $LoginDialog.Title = "Authenticate to OpCon API"

    # Name
    $NameLabel = [Terminal.Gui.Label]::new()
    $NameLabel.Height = 1
    $NameLabel.Width = 45
    $NameLabel.Text = "Environment Name"

    $NameTextfield = [Terminal.Gui.Textfield]::new()
    $NameTextfield.Width = 40
    $NameTextfield.X = [Terminal.Gui.Pos]::Right($NameLabel)

    $LoginDialog.Add($NameLabel) 
    $LoginDialog.Add($NameTextfield)

    # Username
    $UsernameLabel = [Terminal.Gui.Label]::new()
    $UsernameLabel.Height = 1
    $UsernameLabel.Width = 45
    $UsernameLabel.Text = "Username"
    $UsernameLabel.Y = [Terminal.Gui.Pos]::Bottom($NameLabel)

    $UsernameTextfield = [Terminal.Gui.Textfield]::new()
    $UsernameTextfield.Width = 40
    $UsernameTextfield.X = [Terminal.Gui.Pos]::Right($UsernameLabel)
    $UsernameTextfield.Y = [Terminal.Gui.Pos]::Bottom($NameTextfield)

    $LoginDialog.Add($UsernameLabel) 
    $LoginDialog.Add($UsernameTextfield)

    # Password
    $PasswordLabel = [Terminal.Gui.Label]::new()
    $PasswordLabel.Height = 1
    $PasswordLabel.Width = 45
    $PasswordLabel.Text = "Password"
    $PasswordLabel.Y = [Terminal.Gui.Pos]::Bottom($UsernameLabel)

    $PasswordTextfield = [Terminal.Gui.Textfield]::new()
    $PasswordTextfield.Width = 40
    $PasswordTextfield.Secret = $true
    $PasswordTextfield.X = [Terminal.Gui.Pos]::Right($PasswordLabel)
    $PasswordTextfield.Y = [Terminal.Gui.Pos]::Bottom($UsernameTextfield)

    $LoginDialog.Add($PasswordLabel) 
    $LoginDialog.Add($PasswordTextfield)

    # Environment Token
    $TokenLabel = [Terminal.Gui.Label]::new()
    $TokenLabel.Height = 1
    $TokenLabel.Width = 45
    $TokenLabel.Text = "External/API Token"
    $TokenLabel.Y = [Terminal.Gui.Pos]::Bottom($PasswordLabel)

    $TokenTextfield = [Terminal.Gui.Textfield]::new()
    $TokenTextfield.Width = 40
    $TokenTextfield.Secret = $true
    $TokenTextfield.X = [Terminal.Gui.Pos]::Right($TokenLabel)
    $TokenTextfield.Y = [Terminal.Gui.Pos]::Bottom($PasswordTextField)

    $LoginDialog.Add($TokenLabel) 
    $LoginDialog.Add($TokenTextfield)

    # Source URL
    $URLLabel = [Terminal.Gui.Label]::new()
    $URLLabel.Height = 1
    $URLLabel.Width = 45
    $URLLabel.Text = "*URL (https://<server>:<port>)"
    $URLLabel.Y = [Terminal.Gui.Pos]::Bottom($TokenLabel)
 
    $URLTextfield = [Terminal.Gui.Textfield]::new()
    $URLTextfield.Width = 40
    $URLTextfield.X = [Terminal.Gui.Pos]::Right($URLLabel)
    $URLTextfield.Y = [Terminal.Gui.Pos]::Bottom($TokenTextfield)

    $LoginDialog.Add($URLLabel)
    $LoginDialog.Add($URLTextfield)

    # Submit button
    $LoginSubmit = [Terminal.Gui.Button]::new()
    $LoginSubmit.Text = "SUBMIT"
    $LoginSubmit.add_Clicked({ 
        if(!($TokenTextfield.text.ToString() -ne "") -and (($UsernameTextfield.text.ToString()) -and ($PasswordTextfield.text.ToString())))
        { 
            $result = OpCon_Login -url $URLTextfield.text.ToString() -user $UsernameTextfield.text.ToString() -password $PasswordTextfield.text.ToString()
            if($null -eq $result)
            { [Terminal.Gui.MessageBox]::ErrorQuery("Error - Not Authenticated to OpCon", "Bad user/password/url") }
            else 
            { $token = ($result).id }
        }
        elseif($TokenTextfield.text.ToString() -ne "")
        { $token = $TokenTextfield.text.ToString() }
        
        # If successful login
        if(($token -ne "") -and ($null -ne $result))
        {
            $global:opconLogins.Add( [PSCustomObject]@{
                        "name"=$NameTextfield.text.ToString();
                        "username"=$UsernameTextfield.text.ToString();
                        "externalToken"="Token " + $token;
                        "url"=$URLTextfield.text.ToString();
                        "lastLogin"=(Get-Date).ToString();
                        "expires"=$result.validUntil
            } ) | Out-Null

            # Updates the login file with added login
            $global:opconLogins | ConvertTo-Json -Depth 3 -AsArray | Out-String | Out-File ($global:path + "\logins.json") -Force

            # Success message
            [Terminal.Gui.MessageBox]::Query("Authenticated to " + $URLTextfield.text.ToString(), "Success!", @("Close"))

            # Close the window
            [Terminal.Gui.Application]::RequestStop()
        }
        elseif($null -ne $result) 
        { [Terminal.Gui.MessageBox]::ErrorQuery("Error - Not Authenticated to OpCon", "Bad user/password/token or url") }
    })
    $LoginSubmit.Y = [Terminal.Gui.Pos]::Bottom($URLLabel)
    $LoginSubmit.X = [Terminal.Gui.Pos]::Center()
    $LoginDialog.Add($LoginSubmit)

    [Terminal.Gui.Application]::Run($LoginDialog)
}
#endregion

function OpConsole_ReLogin()
{
    $LoginDialog = [Terminal.Gui.Dialog]::new()
    $LoginDialog.Title = "Authenticate to OpCon API"

    # Name
    $NameLabel = [Terminal.Gui.Label]::new()
    $NameLabel.Height = 1
    $NameLabel.Width = 45
    $NameLabel.Text = "Environment Name"

    $NameTextLabel = [Terminal.Gui.Label]::new()
    $NameTextLabel.Height = 1
    $NameTextLabel.Width = 40
    $NameTextLabel.Text = $global:opconLogins[$ConnectionList.SelectedItem].name
    $NameTextLabel.X = [Terminal.Gui.Pos]::Right($NameLabel)

    $LoginDialog.Add($NameLabel) 
    $LoginDialog.Add($NameTextLabel)

    # Username
    $UsernameLabel = [Terminal.Gui.Label]::new()
    $UsernameLabel.Height = 1
    $UsernameLabel.Width = 45
    $UsernameLabel.Text = "Username"
    $UsernameLabel.Y = [Terminal.Gui.Pos]::Bottom($NameLabel)

    $UsernameTextLabel = [Terminal.Gui.Label]::new()
    $UsernameTextLabel.Height = 1
    $UsernameTextLabel.Width = 40
    $UsernameTextLabel.Text = $global:opconLogins[$ConnectionList.SelectedItem].username
    $UsernameTextLabel.X = [Terminal.Gui.Pos]::Right($UsernameLabel)
    $UsernameTextLabel.Y = [Terminal.Gui.Pos]::Bottom($NameTextLabel)

    $LoginDialog.Add($UsernameLabel) 
    $LoginDialog.Add($UsernameTextLabel)

    # Source URL
    $URLLabel = [Terminal.Gui.Label]::new()
    $URLLabel.Height = 1
    $URLLabel.Width = 45
    $URLLabel.Text = "*URL (https://<server>:<port>)"
    $URLLabel.Y = [Terminal.Gui.Pos]::Bottom($UsernameLabel)
    
    $URLTextLabel = [Terminal.Gui.Label]::new()
    $URLTextLabel.Height = 1
    $URLTextLabel.Width = 40
    $URLTextLabel.Text = $global:opconLogins[$ConnectionList.SelectedItem].url
    $URLTextLabel.X = [Terminal.Gui.Pos]::Right($URLLabel)
    $URLTextLabel.Y = [Terminal.Gui.Pos]::Bottom($UsernameTextLabel)

    $LoginDialog.Add($URLLabel)
    $LoginDialog.Add($URLTextLabel)

    # Password
    $PasswordLabel = [Terminal.Gui.Label]::new()
    $PasswordLabel.Height = 1
    $PasswordLabel.Width = 45
    $PasswordLabel.Text = "Password"
    $PasswordLabel.Y = [Terminal.Gui.Pos]::Bottom($URLLabel)

    $PasswordTextfield = [Terminal.Gui.Textfield]::new()
    $PasswordTextfield.Width = 40
    $PasswordTextfield.Secret = $true
    $PasswordTextfield.X = [Terminal.Gui.Pos]::Right($PasswordLabel)
    $PasswordTextfield.Y = [Terminal.Gui.Pos]::Bottom($URLTextLabel)

    $LoginDialog.Add($PasswordLabel) 
    $LoginDialog.Add($PasswordTextfield)

    # Environment Token
    $TokenLabel = [Terminal.Gui.Label]::new()
    $TokenLabel.Height = 1
    $TokenLabel.Width = 45
    $TokenLabel.Text = "External/API Token"
    $TokenLabel.Y = [Terminal.Gui.Pos]::Bottom($PasswordLabel)

    $TokenTextfield = [Terminal.Gui.Textfield]::new()
    $TokenTextfield.Width = 40
    $TokenTextfield.Secret = $true
    $TokenTextfield.X = [Terminal.Gui.Pos]::Right($TokenLabel)
    $TokenTextfield.Y = [Terminal.Gui.Pos]::Bottom($PasswordTextField)

    $LoginDialog.Add($TokenLabel) 
    $LoginDialog.Add($TokenTextfield)

    # Submit button
    $LoginSubmit = [Terminal.Gui.Button]::new()
    $LoginSubmit.Text = "SUBMIT"
    $LoginSubmit.add_Clicked({ 
        if(!($TokenTextfield.text.ToString() -ne "") -and (($global:opconLogins[$ConnectionList.SelectedItem].username) -and ($PasswordTextfield.text.ToString())))
        { 
            $result = OpCon_Login -url $global:opconLogins[$ConnectionList.SelectedItem].url -user $global:opconLogins[$ConnectionList.SelectedItem].username -password $PasswordTextfield.text.ToString()
            $token = ($result).id 
        }
        elseif($TokenTextfield.text.ToString() -ne "")
        { $token = $TokenTextfield.text.ToString() }
        
        # If successful login
        if($token -ne "")
        {
            $global:opconLogins[$ConnectionList.SelectedItem].externalToken = "Token " + $token
            $global:opconLogins[$ConnectionList.SelectedItem].lastLogin = (Get-Date).ToString()
            $global:opconLogins[$ConnectionList.SelectedItem].expires = $result.validUntil

            # Success message
            [Terminal.Gui.MessageBox]::Query("Authenticated to " + $global:opconLogins[$ConnectionList.SelectedItem].url, "Success!", @("Close"))

            # Close the window
            [Terminal.Gui.Application]::RequestStop()
        }
        else 
        { [Terminal.Gui.MessageBox]::ErrorQuery("Error - Not Authenticated to OpCon", "Go to Menu -> Connect to OpCon`nPress ESC to close this window") }
    })
    $LoginSubmit.Y = [Terminal.Gui.Pos]::Bottom($TokenLabel)
    $LoginSubmit.X = [Terminal.Gui.Pos]::Center()
    $LoginDialog.Add($LoginSubmit)

    [Terminal.Gui.Application]::Run($LoginDialog)
}

function OpConsole_ReloginAlt()
{
    $LoginDialog = [Terminal.Gui.Dialog]::new()
    $LoginDialog.Title = "Authenticate to OpCon API"

    # Name
    $NameLabel = [Terminal.Gui.Label]::new()
    $NameLabel.Height = 1
    $NameLabel.Width = 45
    $NameLabel.Text = "Environment Name"

    $NameTextLabel = [Terminal.Gui.Label]::new()
    $NameTextLabel.Height = 1
    $NameTextLabel.Width = 40
    $NameTextLabel.Text = $global:altOpConLogin.name
    $NameTextLabel.X = [Terminal.Gui.Pos]::Right($NameLabel)

    $LoginDialog.Add($NameLabel) 
    $LoginDialog.Add($NameTextLabel)

    # Username
    $UsernameLabel = [Terminal.Gui.Label]::new()
    $UsernameLabel.Height = 1
    $UsernameLabel.Width = 45
    $UsernameLabel.Text = "Username"
    $UsernameLabel.Y = [Terminal.Gui.Pos]::Bottom($NameLabel)

    $UsernameTextLabel = [Terminal.Gui.Label]::new()
    $UsernameTextLabel.Height = 1
    $UsernameTextLabel.Width = 40
    $UsernameTextLabel.Text = $global:altOpConLogin.username
    $UsernameTextLabel.X = [Terminal.Gui.Pos]::Right($UsernameLabel)
    $UsernameTextLabel.Y = [Terminal.Gui.Pos]::Bottom($NameTextLabel)

    $LoginDialog.Add($UsernameLabel) 
    $LoginDialog.Add($UsernameTextLabel)

    # Source URL
    $URLLabel = [Terminal.Gui.Label]::new()
    $URLLabel.Height = 1
    $URLLabel.Width = 45
    $URLLabel.Text = "*URL (https://<server>:<port>)"
    $URLLabel.Y = [Terminal.Gui.Pos]::Bottom($UsernameLabel)
    
    $URLTextLabel = [Terminal.Gui.Label]::new()
    $URLTextLabel.Height = 1
    $URLTextLabel.Width = 40
    $URLTextLabel.Text = $global:altOpConLogin.url
    $URLTextLabel.X = [Terminal.Gui.Pos]::Right($URLLabel)
    $URLTextLabel.Y = [Terminal.Gui.Pos]::Bottom($UsernameTextLabel)

    $LoginDialog.Add($URLLabel)
    $LoginDialog.Add($URLTextLabel)

    # Password
    $PasswordLabel = [Terminal.Gui.Label]::new()
    $PasswordLabel.Height = 1
    $PasswordLabel.Width = 45
    $PasswordLabel.Text = "Password"
    $PasswordLabel.Y = [Terminal.Gui.Pos]::Bottom($URLLabel)

    $PasswordTextfield = [Terminal.Gui.Textfield]::new()
    $PasswordTextfield.Width = 40
    $PasswordTextfield.Secret = $true
    $PasswordTextfield.X = [Terminal.Gui.Pos]::Right($PasswordLabel)
    $PasswordTextfield.Y = [Terminal.Gui.Pos]::Bottom($URLTextLabel)

    $LoginDialog.Add($PasswordLabel) 
    $LoginDialog.Add($PasswordTextfield)

    # Environment Token
    $TokenLabel = [Terminal.Gui.Label]::new()
    $TokenLabel.Height = 1
    $TokenLabel.Width = 45
    $TokenLabel.Text = "External/API Token"
    $TokenLabel.Y = [Terminal.Gui.Pos]::Bottom($PasswordLabel)

    $TokenTextfield = [Terminal.Gui.Textfield]::new()
    $TokenTextfield.Width = 40
    $TokenTextfield.Secret = $true
    $TokenTextfield.X = [Terminal.Gui.Pos]::Right($TokenLabel)
    $TokenTextfield.Y = [Terminal.Gui.Pos]::Bottom($PasswordTextField)

    $LoginDialog.Add($TokenLabel) 
    $LoginDialog.Add($TokenTextfield)

    # Submit button
    $LoginSubmit = [Terminal.Gui.Button]::new()
    $LoginSubmit.Text = "SUBMIT"
    $LoginSubmit.add_Clicked({ 
        if(!($TokenTextfield.text.ToString() -ne "") -and (($global:altOpConLogin.username) -and ($PasswordTextfield.text.ToString())))
        { 
            $result = OpCon_Login -url $global:altOpConLogin.url -user $global:altOpConLogin.username -password $PasswordTextfield.text.ToString()
            $token = ($result).id 
        }
        elseif($TokenTextfield.text.ToString() -ne "")
        { $token = $TokenTextfield.text.ToString() }
        
        # If successful login
        if($token -ne "")
        {
            $global:altOpConLogin.externalToken = "Token " + $token
            $global:altOpConLogin.lastLogin = (Get-Date).ToString()
            $global:altOpConLogin.expires = $result.validUntil

            # Success message
            [Terminal.Gui.MessageBox]::Query("Authenticated to " + $global:altOpConLogin.url, "Success!", @("Close"))

            # Close the window
            [Terminal.Gui.Application]::RequestStop()
        }
        else 
        { [Terminal.Gui.MessageBox]::ErrorQuery("Error - Not Authenticated to OpCon", "Go to Menu -> Connect to OpCon`nPress ESC to close this window") }
    })
    $LoginSubmit.Y = [Terminal.Gui.Pos]::Bottom($TokenLabel)
    $LoginSubmit.X = [Terminal.Gui.Pos]::Center()
    $LoginDialog.Add($LoginSubmit)

    [Terminal.Gui.Application]::Run($LoginDialog)    
}

function OpConsole_Select_AltEnvironment()
{
    $AltEnvironment = [Terminal.Gui.Dialog]::new()
    $AltEnvironment.Title = "OpCon environment selection"

    $ChoiceLabel = [Terminal.Gui.Label]::new()
    $ChoiceLabel.Height = 1
    $ChoiceLabel.Width = 35
    $ChoiceLabel.Text = "Select an OpCon environment"

    $ChoiceCombo = [Terminal.Gui.ComboBox]::new()
    $ChoiceCombo.Height = 5
    $ChoiceCombo.Width = 50
    $ChoiceCombo.SetSource( @($global:opconLogins.name) )
    $ChoiceCombo.add_SelectedItemChanged({
        $global:altOpConLogin = $global:opconLogins | Where-Object { $_.name -eq $ChoiceCombo.Text.ToString() }
    })
    $ChoiceCombo.X = [Terminal.Gui.Pos]::Right($ChoiceLabel)

    $ChoiceSubmit = [Terminal.Gui.Button]::new()
    $ChoiceSubmit.Text = "SUBMIT"
    $ChoiceSubmit.add_Clicked({
        if(($ChoiceCombo.Text -ne "") -or ($ChoiceCombo.Text -eq "Add New"))
        {   if(((Get-Date -Date $global:altOpConLogin.expires -Format "MM/dd/yyyy hh:mm:ss") -gt (Get-Date -Format "MM/dd/yyyy hh:mm:ss")) -and ($global:altOpConLogin.externalToken -ne ""))
            { [Terminal.Gui.Application]::RequestStop() }
            else 
            { 
                [Terminal.Gui.MessageBox]::ErrorQuery("Error - Not Authenticated to OpCon", "You need to authenticate to the OpCon environment`nPress ESC to close this window") 
                OpConsole_ReloginAlt
            }
        }
        else 
        { [Terminal.Gui.MessageBox]::ErrorQuery("Error - Invalid selection", "You need to select an OpCon environment`nPress ESC to close this window") }
    })
    $ChoiceSubmit.Y = [Terminal.Gui.Pos]::Bottom($ChoiceCombo)
    $ChoiceSubmit.X = [Terminal.Gui.Pos]::Center()

    $AltEnvironment.Add($ChoiceLabel)
    $AltEnvironment.Add($ChoiceCombo)
    $AltEnvironment.Add($ChoiceSubmit)

    [Terminal.Gui.Application]::Run($AltEnvironment)   
}

function OpConsole_Select_Environment()
{
    # Application
    $Window = [Terminal.Gui.Window]::new()
    $Window.Title = "OpConsole (v" + $global:version + ")"
    $Window.add_KeyPress({ param($arg) 
                            if($arg.KeyEvent.Key.ToString() -eq "F2")
                            { $global:MenuBar.OpenMenu() }
                        })
    [Terminal.Gui.Application]::Top.Add($Window)

    BuildMenu -window $Window

    #Connections
    $ConnectionFrame = [Terminal.Gui.FrameView]::new()
    $ConnectionFrame.Width = [Terminal.Gui.Dim]::Percent(35)
    $ConnectionFrame.Height = [Terminal.Gui.Dim]::Fill()
    $ConnectionFrame.Y = [Terminal.Gui.Pos]::Bottom($global:MenuBar)
    $ConnectionFrame.Title = "Connections"
    $Window.Add($ConnectionFrame)

    #Details
    $DetailsFrame = [Terminal.Gui.FrameView]::new()
    $DetailsFrame.Width = [Terminal.Gui.Dim]::Percent(65)
    $DetailsFrame.Height = [Terminal.Gui.Dim]::Fill()
    $DetailsFrame.X = [Terminal.Gui.Pos]::Right($ConnectionFrame)
    $DetailsFrame.Y = [Terminal.Gui.Pos]::Bottom($global:MenuBar)
    $DetailsFrame.Title = "Details"
    $Window.Add($DetailsFrame)

    #Connections content
    $ConnectionList = [Terminal.Gui.ListView]::new()
    $ConnectionList.Width = [Terminal.Gui.Dim]::Fill()
    $ConnectionList.Height = [Terminal.Gui.Dim]::Fill()
    $ConnectionList.SetFocus()
    $ConnectionList.add_OpenSelectedItem( { 
        if($global:opconLogins[$ConnectionList.SelectedItem].name -ne $global:activeOpCon.name)
        { $ActiveLoginButton.Visible = $true }
        else 
        { $ActiveLoginButton.Visible = $false }

        if($global:opconLogins[$ConnectionList.SelectedItem].name -eq "Add New")
        { 
            OpConsole_Login 

            if($global:opconLogins.Count -eq 1)
            { $ConnectionList.SetSource(@($global:opconLogins.name)) }
            else 
            { $ConnectionList.SetSource($global:opconLogins.name) }
        }
        else
        {
            if($global:activeOpCon.name -eq $global:opconLogins[$ConnectionList.SelectedItem].name)
            { $active = "Yes" }
            else
            { $active = "No" }

            $ConnectionDetails.Text = "URL = " + $global:opconLogins[$ConnectionList.SelectedItem].URL + 
                                  "`n`nUSER = " + $global:opconLogins[$ConnectionList.SelectedItem].username + 
                                  "`n`nLAST LOGIN = " + $global:opconLogins[$ConnectionList.SelectedItem].lastLogin + 
                                  "`n`nLOGIN EXPIRES = " + $global:opconLogins[$ConnectionList.SelectedItem].expires + 
                                  "`n`nACTIVE = " + $active
        }
    } )
    $ConnectionFrame.Add($ConnectionList)

    # Details content
    $ConnectionDetails = [Terminal.Gui.Label]::new()
    $ConnectionDetails.Height = [Terminal.Gui.Dim]::Percent(90)
    $ConnectionDetails.Width = [Terminal.Gui.Dim]::Fill()
    $DetailsFrame.Add($ConnectionDetails)

    # Make connection active
    $ActiveLoginButton = [Terminal.Gui.Button]::new()
    $ActiveLoginButton.Text = "MAKE ACTIVE CONNECTION"
    $ActiveLoginButton.add_Clicked({ 
        if($ConnectionList.SelectedItem)
        {
            $ActiveLoginButton.Visible = $false
            
            if( ( (Get-Date -Date $global:opconLogins[$ConnectionList.SelectedItem].expires -Format "MM/dd/yyyy hh:mm:ss") -lt (Get-Date -Format "MM/dd/yyyy hh:mm:ss")) -or ($global:opconLogins[$ConnectionList.SelectedItem].externalToken -eq "") )
            { OpConsole_ReLogin }

            $global:activeOpCon = $global:opconLogins[$ConnectionList.SelectedItem]
            $ConnectionDetails.Text = "URL = " + $global:opconLogins[$ConnectionList.SelectedItem].URL + 
                                      "`n`nUSER = " + $global:opconLogins[$ConnectionList.SelectedItem].username + 
                                      "`n`nLAST LOGIN = " + $global:opconLogins[$ConnectionList.SelectedItem].lastLogin + 
                                      "`n`nLOGIN EXPIRES = " + $global:opconLogins[$ConnectionList.SelectedItem].expires + 
                                      "`n`nACTIVE = Yes"
        }
    })
    $ActiveLoginButton.Y = [Terminal.Gui.Pos]::Bottom($ConnectionDetails)
    $ActiveLoginButton.X = [Terminal.Gui.Pos]::Center()
    $ActiveLoginButton.Visible = $false
    $DetailsFrame.Add($ActiveLoginButton)

    # Remove connection
    $RemoveLoginButton = [Terminal.Gui.Button]::new()
    $RemoveLoginButton.Text = "REMOVE CONNECTION"
    $RemoveLoginButton.add_Clicked({ 
        $confirm = [Terminal.Gui.MessageBox]::Query("Remove connection", ("Are you sure you want to remove " + $global:opconLogins[$ConnectionList.SelectedItem].name + "?"),@("Remove","Cancel")) 

        if($confirm -eq 0)
        {
            # Checks to see if it was the active connection and clears if so
            if($global:activeOpCon.name -eq $global:opconLogins[$ConnectionList.SelectedItem].name)
            { 
                $global:activeOpCon = ""
                $ActiveLoginButton.Text = "MAKE ACTIVE CONNECTION"
            }

            # Updates the array
            $global:opconLogins.Remove($global:opconLogins[$ConnectionList.SelectedItem])
            
            # Updates the views
            if($global:opconLogins.Count -eq 1)
            { $ConnectionList.SetSource(@($global:opconLogins.name)) }
            else 
            { $ConnectionList.SetSource($global:opconLogins.name) }

            $ConnectionDetails.Text = ""

            # Updates the login file with added login
            $global:opconLogins | ConvertTo-Json -Depth 3 -AsArray | Out-String | Out-File ($global:path + "\logins.json") -Force
        }
    })
    $RemoveLoginButton.Y = [Terminal.Gui.Pos]::Bottom($ActiveLoginButton)
    $RemoveLoginButton.X = [Terminal.Gui.Pos]::Center()
    $RemoveLoginButton.Visible = $true
    $DetailsFrame.Add($RemoveLoginButton)


    if($global:opconLogins.Count -eq 1)
    { $ConnectionList.SetSource(@($global:opconLogins.name)) }
    else 
    { $ConnectionList.SetSource($global:opconLogins.name) }

    [Terminal.Gui.Application]::Run()
}