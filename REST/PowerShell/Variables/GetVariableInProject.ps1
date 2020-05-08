#Gets the Project Variable Set ID to later be used to pull down the variables. This will be exclusive to Space
Function Get-OctopusProject {
    # Define parameters
    param(
        $OctopusServerUrl,
        $ApiKey,
        $ProjectName,
        $SpaceId
    )
    $projectList = Invoke-RestMethod "$OctopusServerUrl/api/projects?Name=$ProjectName" -Headers @{"X-Octopus-ApiKey" = $ApiKey }
    $projectFilter = @($projectList.Items | Where {$_.Name -eq $ProjectName -and $_.SpaceId -eq $SpaceId})
    $projectVariableSetId = $projectFilter[0].VariableSetId
    return $projectVariableSetId
}

#Gets the Project Variables
Function Get-OctopusProjectVariables {
    # Define parameters
    param(
        $OctopusDeployProject,
        $OctopusServerUrl,
        $ApiKey
    )
    return (Invoke-RestMethod -Method "get" -Uri "$OctopusServerUrl/api/variables/$($OctopusDeployProject)" -Headers @{"X-Octopus-ApiKey" = "$ApiKey" })
}

#Gets the Environment ID from the Environment Name. Scoped to Space
Function Get-EnvironmentId{
    # Define parameters
    param(
        $EnvironmentName,
        $SpaceId
    )
    $environmentName = $EnvironmentName
    $environmentList = Invoke-RestMethod "$OctopusServerUrl/api/$spaceId/environments?skip=0&take=1000&name=$environmentName" -Headers @{"X-Octopus-ApiKey"=$ApiKey}
    $environmentFilter = @($environmentList.Items | Where {$_.Name -eq $environmentName})
    $environmentId = $environmentFilter[0].Id
    return $environmentId
}

#Gets the Space ID Based on the Name given
Function Get-SpaceId{
    # Define parameters
    param(
        $Space,
        $OctopusServerUrl,
        $ApiKey
    )
    $spaceList = Invoke-RestMethod "$OctopusServerUrl/api/spaces?Name=$Space" -Headers @{"X-Octopus-ApiKey" = $ApiKey }
    $spaceFilter = @($spaceList.Items | Where {$_.Name -eq $Space})
    $spaceId = $spaceFilter[0].Id
    return $spaceId
}

#Returns the variable value based on space. If you want the variable scoped, you must provide environment name and spaceId
Function Get-Variable {

    # Define parameters
    param(
        $VariableSet,
        $VariableName,
        $Environment,
        $SpaceId
    )
    $OutputVariable = $null
    $EnvScopeValueSet = $False
    $FoundEnvironmentWithinVariable = $false
    if ($Environment){
        $EnvironmentId = Get-EnvironmentId -EnvironmentName $Environment -SpaceId $SpaceId
    }
    #Loop through the variables
    ForEach ($variable in $VariableSet.Variables){
        #Find matching varable by name
        if ($variable.Name -eq $VariableName) {
            #Check if it has an environment scope. If it doesnt, and no EnvScopeValue has been found and set, set it.
            if (!$variable.Scope.Environment -and !$EnvScopeValueSet) {
                $OutputVariable = $variable.Value
            }
            #If there is a scoped environment and variable has not been set
            if ($variable.Scope.Environment -and !$EnvScopeValueSet) {
                #Iterate through the environments and see if our environment is one of them. Set flag to true if it is.
                ForEach ($element in $variable.Scope.Environment){
                    if ($element -eq $EnvironmentId){
                    $FoundEnvironmentWithinVariable = $true
                    }
                }
                #If we have found the environment earlier, set the value, set the flag that we've set the value.
                if ($FoundEnvironmentWithinVariable){
                    $OutputVariable = $variable.Value
                    $EnvScopeValueSet = $True
                    }
            }
        }
    }
    return $OutputVariable
}

################ INPUT THESE VALUES ################
$OctopusServerUrl = "" #PUT YOUR SERVER LOCATION HERE. (e.g. http://localhost)
$ApiKey = "" #PUT YOUR API KEY HERE
$ProjectName = "" #PUT THE NAME OF THE PROJECT THAT HOUSES THE VARIABLES HERE
$SpaceName = ""         #PUT THE NAME OF THE SPACE THAT HAS THE PROJECT IN IT
$CurrentEnv = "" #IF RUNNING FROM A DEPLOYMENT, MAKE THIS EQUAL TO $OctopusParameters["Octopus.Environment.Id"], OTHERWISE PUT ENVIRONMENT NAME

################ INPUT THESE VALUES #################

try {

    #Get Space ID
    $SpaceId = Get-SpaceId -OctopusServerUrl $OctopusServerUrl -ApiKey $ApiKey -Space $SpaceName
    # Get reference to project
    $OctopusProject = Get-OctopusProject -OctopusServerUrl $OctopusServerUrl -ApiKey $ApiKey -ProjectName $ProjectName -SpaceId $SpaceId
    # Get list of existing variables
    $OctopusProjectVariables = Get-OctopusProjectVariables -OctopusDeployProject $OctopusProject -OctopusServerUrl $OctopusServerUrl -ApiKey $ApiKey
     
    #### EXAMPLE ####
    #$tempValue = Get-Variable -VariableSet $OctopusProjectVariables -VariableName "Test" -Environment $CurrentEnv -SpaceId $SpaceId
    #Write-Host "Should be Old: "$tempValue
  
    ################ GET YOUR VARIABLE AND STORE IT HERE ################
 

    ################ GET YOUR VARIABLE AND STORE IT HERE ################
}
catch {
    Write-Error $_.Exception.Message

    throw
}
