Function Get-OctopusProject {
    # Define parameters
    param(
        $OctopusServerUrl,
        $ApiKey,
        $ProjectName,
        $SpaceId
    )
    # Call API to get all projects, then filter on name
    $octopusProject = Invoke-RestMethod -Method "get" -Uri "$OctopusServerUrl/api/projects/all" -Headers @{"X-Octopus-ApiKey" = "$ApiKey" }

    # return the specific project
    return ($octopusProject | Where-Object { $_.Name -eq $ProjectName -and $_.SpaceId -eq $SpaceId})
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
    return (Invoke-RestMethod -Method "get" -Uri "$OctopusServerUrl/api/variables/$($OctopusDeployProject.VariableSetId)" -Headers @{"X-Octopus-ApiKey" = "$ApiKey" })
}

Function Get-SpaceId {
    # Define parameters
    param(
        $Space
    )
    $spaceName = $Space
    $spaceList = Invoke-RestMethod "$OctopusServerUrl/api/spaces?Name=$spaceName" -Headers @{"X-Octopus-ApiKey" = $ApiKey }
    $spaceFilter = @($spaceList.Items | Where { $_.Name -eq $spaceName })
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
    $environmentFilter = @($environmentList.Items | Where { $_.Name -eq $environmentName })
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
        $SpaceName
    )

    #If given a scope parameter, find the matching variable with scope and modify the value
    if ($VariableEnvScope) {

        #Code to transform the environment name to environment ID.
        $SpaceId = Get-SpaceId -Space $SpaceName
        $environmentId = Get-EnvironmentId -EnvironmentName $VariableEnvScope -SpaceId $SpaceId

        #loop through all variables and change the value if the name and environment ID match
        ForEach ($variable in $VariableSet.Variables) {
            if ($variable.Name -eq $VariableName -and $variable.Scope.Environment -eq $environmentId) {
                $variable.Value = $VariableValue
            }
        }
    }
    #When a scope parameter is not given
    else {
        #Find the variable you want to edit by name, then edit the value. Only edit if the variable is unscoped.
        ForEach ($variable in $VariableSet.Variables) {
            if ($variable.Name -eq $VariableName -and !$variable.Scope.Environment) {
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
        $VariableRoleScope

    )
    #Create the variable object    
    $obj = New-Object -Type PSObject -Property @{
        'Name'   = $($VariableName)
        'Value' = $($VariableValue)
        'Type' = 'String'
        'IsSensitive' = $false
        'Scope' = @{
          'Environment' =@()
          'Role' =@()
        }
    }

    #Check to see if an environment was passed, add it to the object if it was
    if ($VariableEnvScope){
        #If the environment passed was an array, add them all
        if ($VariableEnvScope -is [array]){
            foreach ($environment in $variableenvscope){
                $environmentObj = $VariableSet.ScopeValues.Environments | Where { $_.Name -eq $environment } | Select -First 1
                $obj.scope.Environment += $environmentObj.Id
            }
        }
        #If it's not an array, just add the one.
        else{
            $environmentObj = $VariableSet.ScopeValues.Environments | Where { $_.Name -eq $VariableEnvScope } | Select -First 1
            $obj.scope.environment += $environmentObj.Id
        }
    }

    #Check to see if a role was passed, add it to the object if it was
    if ($VariableRoleScope){
        #If the role passed was an array, add them all
        if ($VariableRoleScope -is [array]){
            foreach ($role in $VariableRoleScope){
                $obj.scope.role += $VariableRoleScope
            }
        }
        #If it's not an array, just add the one.
        else{
            $obj.scope.role += $VariableRoleScope
        }
    }
    #add the variable to the variable set
    $VariableSet.Variables += $obj
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

    #If you want to modify an Environmentally scoped variable, you must pass the Environment with -VariableEnvScope and the Space with -SpaceName. Note, if you have multiple environments scoped if it matches on one it will modify the variable, it doesn't need to match on all.

    #Modify-Variable -VariableSet $octopusProjectVariables -VariableName "Test" -VariableValue "New" 
    #Modify-Variable -VariableSet $octopusProjectVariables -VariableName "Test2" -VariableValue "New2" -VariableEnvScope "Development" -SpaceName "Default"
    #Add-Variable -VariableSet $octopusProjectVariables -VariableName "TestNew3" -VariableValue "Nothing scoped"
    #Add-Variable -VariableSet $octopusProjectVariables -VariableName "TestNewEnv2" -VariableValue "Env Scoped" -VariableEnvScope "Development"
    #Add-Variable -VariableSet $octopusProjectVariables -VariableName "TestNewRole" -VariableValue "Role Scoped" -VariableRoleScope "Web"
    #Add-Variable -VariableSet $octopusProjectVariables -VariableName "ObjectTesting2" -VariableValue "Both Env and Role Scoped" -VariableEnvScope "Development" -VariableRoleScope "Web"
    
    ###Example of adding multiple Environments or Roles###

    #$environments = "Development","Test","Production"
    #$roles = "Web","Web-Local"
    #Add-Variable -VariableSet $octopusProjectVariables -VariableName "ArrayTesting" -VariableValue "multi environment and role scope" -VariableEnvScope $environments -VariableRoleScope $roles

    ##### PUT ANY MODIFY AND ADD COMMANDS HERE #####

    
    ##### PUT ANY MODIFY AND ADD COMMANDS HERE #####

    # Convert object to json to upload it
    $jsonBody = $octopusProjectVariables | ConvertTo-Json -Depth 10
    #Write-Host $jsonBody
    # Save the variables to the variable set
    Invoke-RestMethod -Method "put" -Uri "$OctopusServerUrl/api/variables/$($octopusProjectVariables.Id)" -Body $jsonBody -Headers @{"X-Octopus-ApiKey"=$ApiKey}
    

}
catch {
    Write-Error $_.Exception.Message

    throw
}
