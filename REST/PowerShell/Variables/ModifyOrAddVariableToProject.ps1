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

#Code to go find the spaceId
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

    #Find the environment ID based on the name given by the parameter.
    $environmentObj = $VariableSet.ScopeValues.Environments | Where { $_.Name -eq $VariableEnvScope } | Select -First 1
    
    #If there is no Env or Role scope, add variable this way
    if (!$VariableEnvScope -and !$VariableRoleScope) {
        $tempVariable = @{
            Name  = $VariableName
            Value = $VariableValue
            Scope = @{
            }
        }
    }

    #If there is an Env but no Role scope, add variable this way
    if ($VariableEnvScope -and !$VariableRoleScope) {
        $tempVariable = @{
            Name  = $VariableName
            Value = $VariableValue
            Scope = @{ 
                Environment = @(
                    $environmentObj.Id
                )
            }
        }
    }

    #If there is a Role Scope but no Env scope, add the variable this way
    if ($VariableRoleScope -and !$VariableEnvScope) {
        $tempVariable = @{
            Name  = $VariableName
            Value = $VariableValue
            Scope = @{ 
                Role = @(
                    $VariableRoleScope
                )
            }
        }
    }

    #If both scopes exis, add the variable this way
    if ($VariableEnvScope -and $VariableRoleScope) {
        $tempVariable = @{
            Name  = $VariableName
            Value = $VariableValue
            Scope = @{
                Environment = @(
                    $environmentObj.Id
                )
                Role        = @(
                    $VariableRoleScope
                )
            }
        }
    }

    #add the variable to the variable set
    $VariableSet.Variables += $tempVariable
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

    #Examples
    #If you want to modify an Environmentally scoped variable, you must pass the Environment with -VariableEnvScope and the Space with -SpaceName
    #Modify-Variable -VariableSet $octopusProjectVariables -VariableName "Test" -VariableValue "New"
    #Modify-Variable -VariableSet $octopusProjectVariables -VariableName "Test2" -VariableValue "New2" -VariableEnvScope "Development" -SpaceName "Default"
    #Add-Variable -VariableSet $octopusProjectVariables -VariableName "TestNew1" -VariableValue "Nothing to the right"
    #Add-Variable -VariableSet $octopusProjectVariables -VariableName "TestNewEnv" -VariableValue "Env to the right" -VariableEnvScope "Development"
    #Add-Variable -VariableSet $octopusProjectVariables -VariableName "TestNewRole" -VariableValue "Role to the right" -VariableRoleScope "Web"
    #Add-Variable -VariableSet $octopusProjectVariables -VariableName "TestNewEnvRole" -VariableValue "Both to the right" -VariableEnvScope "Development" -VariableRoleScope "Web"

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
