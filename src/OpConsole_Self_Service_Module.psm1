function OpConsole_Self_Service()
{
    if(($global:activeOpCon.externalToken -ne "Token ") -and ($global:activeOpCon.externalToken))
    { 
        # Grab all categories and buttons
        $global:buttons = [System.Collections.ArrayList]@()
        OpCon_GetServiceRequest -url $global:activeOpCon.url -token $global:activeOpCon.externalToken | Sort-Object -Property "Name" | ForEach-Object{ $global:buttons.Add( $_ ) }
        $global:categories = [System.Collections.ArrayList]@()
        OpCon_GetServiceRequestCategory -url $global:activeOpCon.url -token $global:activeOpCon.externalToken | Sort-Object -Property "Name" | ForEach-Object{ $global:categories.Add( $_ ) }

        # Save originals
        #$global:masterButtons = $global:buttons
        #$global:masterCategories = $global:categories
    }

    # Application
    $Window = [Terminal.Gui.Window]::new()
    $Window.Title = "OpConsole (v" + $global:version + ")"
    $Window.add_KeyPress({ param($arg) 
                            if($arg.KeyEvent.Key.ToString() -eq "F2")
                            { $global:MenuBar.OpenMenu() }

                            if($arg.KeyEvent.Key.ToString() -eq "F3")
                            { $SSMenuBar.OpenMenu() }
                        })
    [Terminal.Gui.Application]::Top.Add($Window)

    BuildMenu -window $Window    

    # Menu
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
                        $ExportButton.Visible = $false
                    }
                    else
                    { 
                        # Show the item as checked
                        $MenuItemButtons.Checked = $true
                        $MenuItemCategory.Checked = $false
                        
                        # Remove button for sending button
                        $CategoryButton.Visible = $false
                        $ExportButton.Visible = $true

                        # Clear any text from the right side
                        $Content2.Text = ""
                        $CatButtonListView.SetSource(@())
                        $CatButtonsFrame.Title = "Button Roles"

                        # Verify successful authentication to OpCon
                        if(($global:activeOpCon.externalToken -ne "Token ") -and ($global:activeOpCon.externalToken))
                        { 
                            if($global:buttons.Count -eq 0)
                            { $ListView.SetSource( @() ) }
                            elseif($global:buttons.Count -eq 1)
                            { $ListView.SetSource( @( $global:buttons.name ) ) }
                            else 
                            { $ListView.SetSource($global:buttons.name) }
                        }
                        else 
                        { 
                            $MenuItemButtons.Checked = $false
                            [Terminal.Gui.MessageBox]::ErrorQuery("Error - Not Authenticated to OpCon", "Go to Connection/s -> Select Environment`nPress ESC to close this window") 
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
                        $ExportButton.Visible = $false
                    }
                    else
                    { 
                        # Show the item as checked
                        $MenuItemCategory.Checked = $true
                        $MenuItemButtons.Checked = $false

                        # Remove button for sending button
                        $Button.Visible = $false
                        $ExportButton.Visible = $true

                        # Clear any text from the right side
                        $Content2.Text = ""
                        $CatButtonListView.SetSource(@())
                        $CatButtonsFrame.Title = "Buttons in Category"

                        # Verify successful authentication to OpCon
                        if(($global:activeOpCon.externalToken -ne "Token ") -and ($global:activeOpCon.externalToken))
                        { 
                            if($global:categories.Count -eq 0)
                            { $ListView.SetSource( @() ) }
                            elseif($global:categories.Count -eq 1)
                            { $ListView.SetSource($global:categories.name) }
                            else 
                            { $ListView.SetSource($global:categories.name) }
                        }
                        else 
                        { 
                            $MenuItemCategory.Checked = $false
                            [Terminal.Gui.MessageBox]::ErrorQuery("Error - Not Authenticated to OpCon", "Go to Connection/s -> Select Environment`nPress ESC to close this window") 
                        }
                    }
    } )
    $MenuItemCategory.CheckType = "Checked"
    
    $MenuBarItemSelfService = [Terminal.Gui.MenuBarItem]::new("Self Service (F3)", @($MenuItemButtons,$MenuItemCategory))
    
    $SSMenuBar = [Terminal.Gui.MenuBar]::new(@($MenuBarItemSelfService))
    $SSMenuBar.Y = [Terminal.Gui.Pos]::Bottom($global:MenuBar)
    $Window.Add($SSMenuBar)

    #Frame 1
    $Frame1 = [Terminal.Gui.FrameView]::new()
    $Frame1.Width = [Terminal.Gui.Dim]::Percent(35)
    $Frame1.Height = [Terminal.Gui.Dim]::Fill()
    $Frame1.Y = [Terminal.Gui.Pos]::Bottom($SSMenuBar)
    $Frame1.Title = "Source selection"
    $Window.Add($Frame1)

    #Frame 2
    $Frame2 = [Terminal.Gui.FrameView]::new()
    $Frame2.Width = [Terminal.Gui.Dim]::Percent(65)
    $Frame2.Height = [Terminal.Gui.Dim]::Percent(75)
    $Frame2.X = [Terminal.Gui.Pos]::Right($Frame1)
    $Frame2.Y = [Terminal.Gui.Pos]::Bottom($SSMenuBar)
    $Frame2.Title = "Details"
    $Window.Add($Frame2)

    #Category buttons list frame
    $CatButtonsFrame = [Terminal.Gui.Frameview]::new()
    $CatButtonsFrame.Width = [Terminal.Gui.Dim]::Percent(65)
    $CatButtonsFrame.Height = [Terminal.Gui.Dim]::Percent(20)
    $CatButtonsFrame.Y = [Terminal.Gui.Pos]::Bottom($Frame2)
    $CatButtonsFrame.X = [Terminal.Gui.Pos]::Right($Frame1)
    $CatButtonsFrame.Title = "Additional Information"
    $Window.Add($CatButtonsFrame)

    #Frame 1 content
    $ListView = [Terminal.Gui.ListView]::new()
    $ListView.Width = [Terminal.Gui.Dim]::Fill()
    $ListView.Height = [Terminal.Gui.Dim]::Percent(97)
    $ListView.add_OpenSelectedItem( { 
        if(($MenuItemButtons.Checked -eq $true) -or (($MenuItemButtons.Checked -eq $false) -and ($MenuItemCategory.Checked -eq $false)))
        {
            if(($global:buttons[$ListView.SelectedItem].documentation).Length -gt 150)
            { $buttonDocs = ($global:buttons[$ListView.SelectedItem].documentation).SubString(0,150) }
            else 
            { $buttonDocs = $global:buttons[$ListView.SelectedItem].documentation }

            if(($global:buttons[$ListView.SelectedItem].html).Length -gt 150)
            { $buttonHTML = ($global:buttons[$ListView.SelectedItem].html).SubString(0,150) }
            else 
            { $buttonHTML = $global:buttons[$ListView.SelectedItem].html }

            if($global:buttons[$ListView.SelectedItem].hideRule)
            { $hideRule = $global:buttons[$ListView.SelectedItem].hideRule }

            if($global:buttons[$ListView.SelectedItem].disableRule)
            { $disableRule = $global:buttons[$ListView.SelectedItem].disableRule }

            $Content2.Text = "NAME = " + $global:buttons[$ListView.SelectedItem].name + 
                            "`nDOCUMENTATION = " + $buttonDocs +
                            "`nCATEGORY = " + $global:buttons[$ListView.SelectedItem].serviceRequestCategory.name + 
                            "`nHTML = `n" + $buttonHTML + 
                            "`nDISABLE RULE = " + $disableRule + 
                            "`nHIDE RULE = " + $hideRule
            
            $buttonDetails = OpCon_GetServiceRequest -url $global:activeOpCon.url -token $global:activeOpCon.externalToken -id $global:buttons[$ListView.SelectedItem].id    
            if($buttonDetails.roles)
            {  
                if($buttonDetails.roles.Count -eq 1)
                { $CatButtonListView.SetSource( @($buttonDetails.roles.name) ) }
                else
                { $CatButtonListView.SetSource( ($buttonDetails.roles.name | Sort-Object) ) } 
            }
            else 
            { $CatButtonListView.SetSource( @() ) }

            # Only add the button if buttons have been received
            $Button.Visible = $true
            $CategoryButton.Visible = $false
        }
        elseif($MenuItemCategory.Checked -eq $true)
        {
            if(($global:activeOpCon.externalToken -ne "Token ") -and ($global:activeOpCon.externalToken))
            {
                $buttonsByCategory = ($global:buttons).Where({ $_.serviceRequestCategory.name -Match $global:categories[$ListView.SelectedItem].name })

                $Content2.Text = "CATEGORY =  " + $global:categories[$ListView.SelectedItem].name + 
                                "`nCOLOR = " + $global:categories[$ListView.SelectedItem].color

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
                [Terminal.Gui.MessageBox]::ErrorQuery("Error - Not Authenticated to OpCon", "Go to Connection/s -> Select Environment`nPress ESC to close this window") 
            }
        }
    } )
    $Frame1.Add($ListView)

    #Frame 2 content
    $Content2 = [Terminal.Gui.Label]::new()
    $Content2.Height = [Terminal.Gui.Dim]::Percent(95)
    $Content2.Width = [Terminal.Gui.Dim]::Fill()
    $Frame2.Add($Content2)

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

            # Get Alt OpCon env creds
            OpConsole_Select_AltEnvironment

            # Match category/ids
            $getCategory = OpCon_GetServiceRequestCategory -url $global:altOpConLogin.url -token $global:altOpConLogin.externalToken -category $global:categories[$ListView.selectedItem].name
        
            if($getCategory)
            { $destinationCategory = [PSCustomObject]@{ "id" = $getCategory.id;"name" = $getCategory.name; "color" = $getCategory.color } }
            
            # If Categories were matched/not
            if($destinationCategory)
            { 
                $sourceButtons | ForEach-Object{
                                                $details = OpCon_GetServiceRequest -url $global:activeOpCon.url -token $global:activeOpCon.externalToken -id $_.id
                                                $details.roles = $role
                                                $details.serviceRequestCategory = $destinationCategory
                                                $newButton = OpCon_CreateServiceRequest -url $global:altOpConLogin.url -token $global:altOpConLogin.externalToken -name $details.name -object $details

                                                if($null -eq $newButton)
                                                { [Terminal.Gui.MessageBox]::ErrorQuery("Failed Adding Button", "There was a problem creating the button.`nCheck the terminal output for more details." ) }
                                                else 
                                                { [Terminal.Gui.MessageBox]::Query("Button " + $newbutton.name + " added to " + $global:altOpConLogin.url, "***Success***",@("Close") ) }
                }
            }
            else 
            {
                $sourceButtons | ForEach-Object{
                                                $details = OpCon_GetServiceRequest -url $global:activeOpCon.url -token $global:activeOpCon.externalToken -id $_.id
                                                $details.roles = $role
                                                $newButton = OpCon_CreateServiceRequest -url $global:altOpConLogin.url -token $global:altOpConLogin.externalToken -name $details.name -object ($details | Select-Object -ExcludeProperty "serviceRequestCategory")

                                                if($null -eq $newButton)
                                                { [Terminal.Gui.MessageBox]::ErrorQuery("Failed Adding Button", "There was a problem creating the button.`nCheck the terminal output for more details." ) }
                                                else 
                                                { [Terminal.Gui.MessageBox]::Query("Button " + $newbutton.name + " added to " + $global:altOpConLogin.url, "***Success***",@("Close") ) }
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
            $sourceButton = OpCon_GetServiceRequest -url $global:activeOpCon.url -token $global:activeOpCon.externalToken -id $global:buttons[$ListView.SelectedItem].id

            # Default to ocadm role in destination OpCon
            $sourceButton.roles = @(@{ "id" = 0;"name"="ocadm"})

            # Get Alt OpCon env creds
            OpConsole_Select_AltEnvironment

            # Match category/ids
            if($sourceButton.servicerequestCategory)
            { 
                $getCategory = OpCon_GetServiceRequestCategory -url $global:altOpConLogin.url -token $global:altOpConLogin.externalToken -category $sourceButton.servicerequestCategory.name
            
                if($getCategory)
                { $destinationCategory = [PSCustomObject]@{ "id" = $getCategory.id;"name" = $getCategory.name; "color" = $getCategory.color } }
                
                # If Categories were matched/not
                if($destinationCategory)
                { 
                    $sourceButton.serviceRequestCategory = $destinationCategory
                    $newButton = OpCon_CreateServiceRequest -url $global:altOpConLogin.url -token $global:altOpConLogin.externalToken -object $sourceButton
                }
                else 
                { $newButton = OpCon_CreateServiceRequest -url $global:altOpConLogin.url -token $global:altOpConLogin.externalToken -object ($sourceButton | Select-Object -ExcludeProperty "serviceRequestCategory") }

            }
            else
            { $newButton = OpCon_CreateServiceRequest -url $global:altOpConLogin.url -token $global:altOpConLogin.externalToken -object $sourceButton }

            if($null -eq $newButton)
            { [Terminal.Gui.MessageBox]::ErrorQuery("Failed Adding Button", "There was a problem creating the button.`nCheck the terminal output for more details." ) }
            else 
            { [Terminal.Gui.MessageBox]::Query("Button " + $newbutton.name + " added to " + $global:altOpConLogin.url, "***Success***",@("Close") ) }
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

    # Impex Buttons
    $ImportButton = [Terminal.Gui.Button]::new()
    $ImportButton.Text = "IMPORT FROM FILE"
    $ImportButton.add_Clicked({ 
        $ListView.SetSource(@())
        $MenuItemCategory.Checked = $false
        $MenuItemButtons.Checked = $false
        $Button.Visible = $false

        $ImportDialog = [Terminal.Gui.OpenDialog]::new("Import Items", "")
        $ImportDialog.NameFieldLabel = "Name:"
        [Terminal.Gui.Application]::Run($ImportDialog)

        if(!$ImportDialog.Canceled)
        {
            $global:buttons = [PSCustomObject]( Get-Content $ImportDialog.Filepath.ToString() | Out-String | ConvertFrom-Json -Depth 5) 
            $ListView.SetSource($global:buttons.name)
            $Content2.Text = ""
            $ExportButton.Visible = $true

            [Terminal.Gui.MessageBox]::Query("Import complete", ("Imported " + $global:buttons.Count + " buttons"),"OK") 
        }
    })
    $ImportButton.Y = [Terminal.Gui.Pos]::Bottom($ListView)
    $ImportButton.Visible = $true
    $Frame1.Add($ImportButton)

    $ExportButton = [Terminal.Gui.Button]::new()
    $ExportButton.Text = "EXPORT TO FILE"
    $ExportButton.add_Clicked({ 
        $ExportDialog = [Terminal.Gui.SaveDialog]::new("Export Items", "")
        $ExportDialog.NameFieldLabel = "Name:"
        
        [Terminal.Gui.Application]::Run($ExportDialog)

        if(!$ExportDialog.Canceled)
        {
            if($MenuItemButtons.Checked -eq $true)
            { ($global:buttons | ConvertTo-Json -Depth 5) | Out-String | Out-File $ExportDialog.Filepath.ToString() }
            elseif($MenuItemCategory.Checked -eq $true)
            { ($global:categories | ConvertTo-Json -Depth 5) | Out-String | Out-File $ExportDialog.Filepath.ToString() }
            
            [Terminal.Gui.MessageBox]::Query("Exported items", ("Exported to file: " + $ExportDialog.Filepath.ToString()),"OK")
        }
    })
    $ExportButton.Y = [Terminal.Gui.Pos]::Bottom($ListView)
    $ExportButton.X = [Terminal.Gui.Pos]::Right($ImportButton)
    $ExportButton.Visible = $false
    $Frame1.Add($ExportButton)

    [Terminal.Gui.Application]::Run()
}