function OpCon_Login_CLI($url,$user,$password)
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

function OpCon_GetServiceRequest_CLI($url,$token,$id,$button)
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

function OpCon_CreateServiceRequest_CLI($url,$token,$name,$doc,$html,$details,$disable,$hide,$category,$categoryName,$roles,$object)
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

function OpCon_GetServiceRequestCategory_CLI($url,$token,$category,$id)
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

function OpConsole_CLI($srcUrl,$destUrl,$button,$category,$srcUser,$srcPassword,$destUser,$destPassword,$srcToken,$destToken)
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