Function Get-OctopusProject {
    # Define parameters
    param(
        $OctopusServerUrl,
        $ApiKey,
        $ProjectName,
        $SpaceId
    )
    # Call API to get all projects, then filter on name
    $octopusProject = Invoke-RestMethod -Method "get" -Uri "$OctopusServerUrl/api/$spaceId/projects/all" -Headers @{"X-Octopus-ApiKey" = "$ApiKey" }

    # return the specific project
    return ($octopusProject | Where-Object { $_.Name -eq $ProjectName })
}

Function Get-OctopusProjectVariables {
    # Define parameters
    param(
        $OctopusDeployProject,
        $OctopusServerUrl,
        $ApiKey,
        $SpaceId
    )
    # Get reference to the variable list
    return (Invoke-RestMethod -Method "get" -Uri "$OctopusServerUrl/api/$spaceId/variables/$($OctopusDeployProject.VariableSetId)" -Headers @{"X-Octopus-ApiKey" = "$ApiKey" })
}

Function Get-SpaceId {
    # Define parameters
    param(
        $Space
    )
    $spaceName = $Space
    $spaceList = Invoke-RestMethod "$OctopusServerUrl/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers @{"X-Octopus-ApiKey" = $ApiKey }
    $spaceFilter = @($spaceList.Items | Where-Object { $_.Name -eq $spaceName })
    $spaceId = $spaceFilter[0].Id
    return $spaceId
}

Function Get-EnvironmentId {
    # Define parameters
    param(
        $EnvironmentName,
        $SpaceId
    )
    $environmentList = Invoke-RestMethod "$OctopusServerUrl/api/$spaceId/environments?skip=0&take=1000&name=$environmentName" -Headers @{"X-Octopus-ApiKey" = $ApiKey }
    $environmentFilter = @($environmentList.Items | Where-Object { $_.Name -eq $environmentName })
    $environmentId = $environmentFilter[0].Id
    return $environmentId
}

Function Modify-Variable {
    # Define parameters
    param(
        $VariableSet,
        $VariableName,
        $VariableValue,
        $VariableEnvScope,
        $VariableRoleScope,
        $VariableTenantTagScope,
        $SpaceName
    )
    
    #Function to test if all scopes match
    function Test-ScopeMatch {
        param($VariableScope, $TargetScope)
        
        #If neither have a scope, they match, so return true.
        if (!$TargetScope -and !$VariableScope) { return $true }      
        
        #Code to support comma separated string as well as arrays, this detects if there's a comma in a string and converts it to an array.
        if ($TargetScope -is [string] -and $TargetScope.Contains(',')) {
            $TargetScope = $TargetScope -split ',' | ForEach-Object { $_.Trim() }
        }

        #Make both scopes an array for easier comparison regardless if they are arrays.
        $VariableScopeArray = if ($VariableScope -is [array]) { $VariableScope } else { @($VariableScope) }
        $TargetScopeArray = if ($TargetScope -is [array]) { $TargetScope } else { @($TargetScope) }
        
        #If their counts are different, they dont match. This is to catch when one scope has both of the others, but has extra scopes.
        if ($VariableScopeArray.Count -ne $TargetScopeArray.Count) {
            return $false
        }
        
        #Every target scope must exist in the variable scope
        foreach ($target in $TargetScopeArray) {
            if ($VariableScopeArray -notcontains $target) {
                return $false
            }
        }
        
        #Every variable scope must exist in the target scope
        foreach ($varScope in $VariableScopeArray) {
            if ($TargetScopeArray -notcontains $varScope) {
                return $false
            }
        }
        
        return $true
    }
    
    #If we are matching on ANY scope, test matching
    if ($VariableEnvScope -or $VariableRoleScope -or $VariableTenantTagScope) {
        
        #Create environment IDs out of names.
        $environmentIds = $null
        if ($VariableEnvScope) {
            $SpaceId = Get-SpaceId -Space $SpaceName
            if ($VariableEnvScope -is [array]) {
                $environmentIds = @()
                foreach ($env in $VariableEnvScope) {
                    $environmentIds += Get-EnvironmentId -EnvironmentName $env -SpaceId $SpaceId
                }
            } else {
                $environmentIds = Get-EnvironmentId -EnvironmentName $VariableEnvScope -SpaceId $SpaceId
            }
        }
        
        #Check each variable and if they match, change it.
        ForEach ($variable in $VariableSet.Variables) {
            if ($variable.Name -eq $VariableName) {
                $environmentMatch = Test-ScopeMatch -VariableScope $variable.Scope.Environment -TargetScope $environmentIds
                $roleMatch = Test-ScopeMatch -VariableScope $variable.Scope.Role -TargetScope $VariableRoleScope
                $tenantTagMatch = Test-ScopeMatch -VariableScope $variable.Scope.TenantTag -TargetScope $VariableTenantTagScope
                
                # Only modify if all specified scopes match
                if ($environmentMatch -and $roleMatch -and $tenantTagMatch) {
                    $variable.Value = $VariableValue
                }
            }
        }
    }
    #If no scopes are provided, we will check to see if the names match and the corresponding variable has no scopes.
    else {
        ForEach ($variable in $VariableSet.Variables) {
            if ($variable.Name -eq $VariableName -and !$variable.Scope.Environment -and !$variable.Scope.Role -and !$variable.Scope.TenantTag) {
                $variable.Value = $VariableValue
            }
        }
    }
}


Function Add-Variable {

    # Define parameters
    param(
        $VariableSet,
        $VariableName,
        $VariableValue,
        $VariableEnvScope,
        $VariableRoleScope,
        $IsSensitive = $false

    )
    #Create the variable object    
    $obj = New-Object -Type PSObject -Property @{
        'Name'        = $($VariableName)
        'Value'       = $($VariableValue)
        'Type'        = 'String'
        'IsSensitive' = $IsSensitive
        'Scope'       = @{
            'Environment' = @()
            'Role'        = @()
        }
    }

    #Check to see if an environment was passed, add it to the object if it was
    if ($VariableEnvScope) {
        #If the environment passed was an array, add them all
        if ($VariableEnvScope -is [array]) {
            foreach ($environment in $variableenvscope) {
                $environmentObj = $VariableSet.ScopeValues.Environments | Where-Object { $_.Name -eq $environment } | Select-Object -First 1
                $obj.scope.Environment += $environmentObj.Id
            }
        }
        #If it's not an array, just add the one.
        else {
            $environmentObj = $VariableSet.ScopeValues.Environments | Where-Object { $_.Name -eq $VariableEnvScope } | Select-Object -First 1
            $obj.scope.environment += $environmentObj.Id
        }
    }

    #Check to see if a role was passed, add it to the object if it was
    if ($VariableRoleScope) {
        #If the role passed was an array, add them all
        if ($VariableRoleScope -is [array]) {
            foreach ($role in $VariableRoleScope) {
                $obj.scope.role += $VariableRoleScope
            }
        }
        #If it's not an array, just add the one.
        else {
            $obj.scope.role += $VariableRoleScope
        }
    }
    #add the variable to the variable set
    $VariableSet.Variables += $obj
}

Function Remove-Variable {
    param(
        $VariableSet,
        $VariableName
    )

    $tempVars = @()
 
    foreach ($variable in $VariableSet.Variables) {
        if ($variable.Name -ne $VariableName) {
            $tempVars += $variable
        }
    }
    $variableset.Variables = $tempVars
}

Function Modify-Scope {
    param(
        $VariableSet,
        $VariableName,
        $VariableEnvScope,
        $VariableRoleScope,
        $ExistingEnvScope,
        $ExistingRoleScope,
        $IsSensitive = $false
    )
    $tempVars = @()
    #Create the variable object    
    $obj = New-Object -Type PSObject -Property @{
        'Name'        = $($VariableName)
        'Value'       = $($VariableValue)
        'Type'        = 'String'
        'IsSensitive' = $IsSensitive
        'Scope'       = @{
            'Environment' = @()
            'Role'        = @()
        }
    }

    if ($VariableRoleScope) {
        #If the role passed was an array, add them all
        if ($VariableRoleScope -is [array]) {
            foreach ($role in $VariableRoleScope) {
                $obj.scope.role += $role
            }
        }
        #If it's not an array, just add the one.
        else {
            $obj.scope.role += $VariableRoleScope
        }
    }

    if ($VariableEnvScope) {
        #If the environment passed was an array, add them all
        if ($VariableEnvScope -is [array]) {
            foreach ($environment in $variableenvscope) {
                $environmentObj = $VariableSet.ScopeValues.Environments | Where-Object { $_.Name -eq $environment } | Select-Object -First 1
                $obj.scope.Environment += $environmentObj.Id
            }
        }
        #If it's not an array, just add the one.
        else {
            $environmentObj = $VariableSet.ScopeValues.Environments | Where-Object { $_.Name -eq $VariableEnvScope } | Select-Object -First 1
            $obj.scope.environment += $environmentObj.Id
        }
    }
    #iterate each variable to match on the one we want to modify
    foreach ($variable in $VariableSet.Variables) {
        $envmatch = $null
        $rolematch = $null
        $temprolelist = @()
        $tempenvlist = @()
        $tempExistList = @()
        $envDiffs = $null
        $roleDiffs = $null
        #create list of environments based on IDs
        foreach ($env in $ExistingEnvScope) {
            $tempId = $VariableSet.ScopeValues.Environments | Where-Object { $_.Name -eq $env } | Select-Object -First 1
            $tempExistList += $tempId.Id
        }

        #put the scopes in a format we can compare
        foreach ($env in $variable.Scope.Environment) {
            $tempenvlist += $env
        }
        #sort to compare
        $tempenvlist = $tempenvlist | sort
        $tempExistList = $tempExistList | sort
        #test compare
        if ($null -ne $tempenvlist -and $null -ne $tempExistList) {
            $envDiffs = Compare-Object -ReferenceObject $tempenvlist -DifferenceObject $tempExistList -PassThru
        }
        
        $envmatch  =($null -eq $envDiffs)
        
        # Same as above but for roles
        foreach ($role in $variable.Scope.Role) {
            $temprolelist += $role
        }
        $temprolelist = $temprolelist | sort
        $ExistingRoleScope = $ExistingRoleScope | sort

        if (!$null -eq $temprolelist -and !$null -eq $ExistingRoleScope) {
            $roleDiffs = Compare-Object -ReferenceObject $temprolelist -DifferenceObject $ExistingRoleScope -PassThru
        }

        $rolematch = ($null -eq $roleDiffs)

        # If everything matches, add the value from the matched variable and add the dummy variable to the set
        if (($variable.Name -eq $VariableName) -and ($rolematch) -and ($envmatch)) {
            $obj.Value = $variable.Value
            
            # Keep original Machine/Action/Channel/ProcessOwner scopes
            if ($variable.Scope.Machine) {
                $obj.Scope.Machine = $variable.Scope.Machine
            }
            if ($variable.Scope.Action) {
                $obj.Scope.Action = $variable.Scope.Action
            }
            if ($variable.Scope.Channel) {
                $obj.Scope.Channel = $variable.Scope.Channel
            }
            if ($variable.Scope.ProcessOwner) {
                $obj.Scope.ProcessOwner = $variable.Scope.ProcessOwner
            }
            $tempVars += $obj
        }
        #otherwise add the variable without modifying
        else {
            $tempVars += $variable
        }
    }

    $variableset.Variables = $tempVars
}

### INPUT THESE VALUES ####

$OctopusServerUrl = ""  #PUT YOUR SERVER LOCATION HERE. (e.g. http://localhost)
$ApiKey = ""   #PUT YOUR API KEY HERE
$ProjectName = ""   #PUT THE NAME OF THE PROJECT THAT HOUSES THE VARIABLES HERE
$SpaceName = "" #PUT THE NAME OF THE SPACE THAT HOUSES THE PROJECT HERE

### INPUT THESE VALUES ####
try {
    # Convert SpaceName to SpaceId
    $SpaceId = Get-SpaceId -Space $SpaceName
    # Get reference to project
    $octopusProject = Get-OctopusProject -OctopusServerUrl $OctopusServerUrl -ApiKey $ApiKey -ProjectName $ProjectName -SpaceId $SpaceId
    # Get list of existing variables
    $octopusProjectVariables = Get-OctopusProjectVariables -OctopusDeployProject $octopusProject -OctopusServerUrl $OctopusServerUrl -ApiKey $ApiKey -SpaceId $SpaceId

    ###Examples###

    #--------------------------
    #Modify-Variable Information
    #--------------------------
    #If you want to modify a variable with scopes, you must pass EVERY scope. It will try to find the variable value that has all of the matching scopes and modify that one. 

    #Modify-Variable -VariableSet $octopusProjectVariables -VariableName "Test" -VariableValue "NewEnvScope" -VariableEnvScope "Development" -SpaceName "Default"
    #Modify-Variable -VariableSet $octopusProjectVariables -VariableName "Test" -VariableValue "NewEnvRoleScope" -VariableEnvScope "Development" -VariableRoleScope "BestServers" -SpaceName "Default"
    #Modify-Variable -VariableSet $octopusProjectVariables -VariableName "Test" -VariableValue "NewEnvRoleTenantScope" -VariableEnvScope "Development" -VariableRoleScope "SecondBestServers" -VariableTenantTagScope "Tenants/Coke, Tenants/Pepsi" -SpaceName "Default"
    #$tenants = @("Tenants/Sprite", "Tenants/Barqs")
    #Modify-Variable -VariableSet $octopusProjectVariables -VariableName "Test" -VariableValue "NewEnvRoleTenantScope" -VariableEnvScope "Development" -VariableRoleScope "SecondBestServers" -VariableTenantTagScope $tenants -SpaceName "Default"

    #--------------------------
    #Add-Variable Information
    #--------------------------
    #Add-Variable -VariableSet $octopusProjectVariables -VariableName "TestNew555" -VariableValue "Nothing scoped"
    #Add-Variable -VariableSet $octopusProjectVariables -VariableName "TestNewEnv2" -VariableValue "Env Scoped" -VariableEnvScope "Development"
    #Add-Variable -VariableSet $octopusProjectVariables -VariableName "TestNewRole" -VariableValue "Role Scoped" -VariableRoleScope "Web"
    #Add-Variable -VariableSet $octopusProjectVariables -VariableName "ObjectTesting2" -VariableValue "Both Env and Role Scoped" -VariableEnvScope "Development" -VariableRoleScope "Web"
    
    #If you want to add a variable as sensitive, set the parameter -IsSensitive $true. It will default to $false otherwise.

    #Add-Variable -VariableSet $octopusProjectVariables -VariableName "SensitiveVariable" -VariableValue "SENSITIVE" -VariableEnvScope "Development" -VariableRoleScope "Web" -IsSensitive $true
    #Add-Variable -VariableSet $octopusProjectVariables -VariableName "NOTSensitiveVariable" -VariableValue "not SENSITIVE" -VariableEnvScope "Development" -VariableRoleScope "Web"
    
    ###Example of adding multiple Environments or Roles###

    #$environments = "Development","Test","Production"
    #$roles = "Web","Web-Local"
    #Add-Variable -VariableSet $octopusProjectVariables -VariableName "ArrayTesting2" -VariableValue "multi environment and role scope" -VariableEnvScope $environments -VariableRoleScope $roles
    
    #--------------------------
    #Remove-Variable Information
    #--------------------------
    #Remove-Variable will delete any variable with the name regardless of scoping

    #Remove-Variable -VariableSet $octopusProjectVariables -VariableName "RemoveThis"
    
    #--------------------------
    #Modify-Scope Information
    #--------------------------
    #To use this function, you have to define both the existing environments+roles on the variable in array format, and the resulting environments+roles that you want it to have at the end of the function, also in array format.
    
    #For example, this would find the variable with Env scope of Development, and role scope of Web, then remove both of them.
    #$newEnvironments = @()
    #$newRoles = @()
    #$existingEnvironments = @("Development")
    #$existingRoles = @("Web")
    #Modify-Scope -VariableSet $octopusProjectVariables -VariableName "ObjectTesting2" -VariableEnvScope $newEnvironments -VariableRoleScope $newRoles -ExistingEnvScope $existingEnvironments  -ExistingRoleScope $existingRoles
    
    #In this example, this would find the variable with Env scope of Development, and role scope of Web, then add the Test environment, and the Windows role scopes.
    #$newEnvironments = @("Development","Test")
    #$newRoles = @("Web","Windows")
    #$existingEnvironments = @("Development")
    #$existingRoles = @("Web")
    #Modify-Scope -VariableSet $octopusProjectVariables -VariableName "ObjectTesting2" -VariableEnvScope $newEnvironments -VariableRoleScope $newRoles -ExistingEnvScope $existingEnvironments  -ExistingRoleScope $existingRoles


    ##### PUT ANY MODIFY AND ADD COMMANDS HERE #####

    
    ##### PUT ANY MODIFY AND ADD COMMANDS HERE #####

    # Convert object to json to upload it
    #$octopusProjectVariables.Version++
    $jsonBody = $octopusProjectVariables | ConvertTo-Json -Depth 10
    #Write-Host $jsonBody
    # Save the variables to the variable set
    Invoke-RestMethod -Method "put" -Uri "$OctopusServerUrl/api/$spaceId/variables/$($octopusProjectVariables.Id)" -Body $jsonBody -Headers @{"X-Octopus-ApiKey" = $ApiKey }
    

}
catch {
    Write-Error $_.Exception.Message

    throw
}
