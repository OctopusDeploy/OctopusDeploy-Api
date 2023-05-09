#Returns the variable value based on space. If you want the variable scoped, you must provide environment name and spaceId
Function Get-VariableValue {
    param(
        $Options,
        $VariableSet,
        $VariableName,
        $Environment
    )

    $outputVariable = $null
    $envScopeValueSet = $False
    $foundEnvironmentWithinVariable = $false

    if ($Environment) {
        $environmentList = Invoke-RestMethod "$($Options.OctopusUrl)/environments/all" -Headers $Options.Headers
        $environment = $environmentList | Where-Object { $_.Name -eq $environment }
        $environmentId = $environment.Id
    }

    #Find matching varable by name
    $variables = $VariableSet.Variables | Where-Object { $_.Name -eq $VariableName }

    #Loop through the variable
    ForEach ($variable in $variables) {
        #Check if it has an environment scope. If it doesnt, and no EnvScopeValue has been found and set, set it.
        if (!$variable.Scope.Environment -and !$envScopeValueSet) {
            $outputVariable = $variable.Value
        }
        #If there is a scoped environment and variable has not been set
        if ($variable.Scope.Environment -and !$envScopeValueSet) {
            #Iterate through the environments and see if our environment is one of them. Set flag to true if it is.
            ForEach ($element in $variable.Scope.Environment) {
                if ($element -eq $environmentId) {
                    $foundEnvironmentWithinVariable = $true
                }
            }
            #If we have found the environment earlier, set the value, set the flag that we've set the value.
            if ($foundEnvironmentWithinVariable) {
                $outputVariable = $variable.Value
                $envScopeValueSet = $True
            }
        }
    }

    return $outputVariable
}

################ INPUT THESE VALUES ################
$OctopusServerUrl = "" #PUT YOUR SERVER LOCATION HERE. (e.g. http://localhost)
$ApiKey = "" #PUT YOUR API KEY HERE
$ProjectName = "" #PUT THE NAME OF THE PROJECT THAT HOUSES THE VARIABLES HERE
$SpaceName = ""         #PUT THE NAME OF THE SPACE THAT HAS THE PROJECT IN IT
$CurrentEnv = "" #PUT ENVIRONMENT NAME HERE

################ INPUT THESE VALUES #################

try {
    $headers = @{ "X-Octopus-ApiKey" = $ApiKey }
    $spaceList = Invoke-RestMethod "$OctopusServerUrl/api/spaces/all" -Headers $headers
    $space = $spaceList | Where-Object { $_.Name -eq $SpaceName }

    $url = "$OctopusServerUrl/api/$($space.Id)"
    $headers = @{ "X-Octopus-ApiKey" = $ApiKey }

    # Get Variable set
    $projectList = Invoke-RestMethod "$url/projects/all" -Headers $headers
    $project = $projectList | Where-Object { $_.Name -eq $ProjectName }
    $projectVariableSetId = $project.VariableSetId

    $variableSet = Invoke-RestMethod -Method "get" -Uri "$url/variables/$projectVariableSetId" -Headers $headers
    $Options = @{
        OctopusUrl = "$OctopusServerUrl/api/$($space.Id)"
        Headers    = @{ "X-Octopus-ApiKey" = $ApiKey }
        }

    #### EXAMPLE ####
    $tempValue = Get-VariableValue -Options $Options -VariableSet $VariableSet -VariableName "Test" -Environment $CurrentEnv
    Write-Host "Should be Old: "$tempValue
    ################ GET YOUR VARIABLE AND STORE IT HERE ################


    ################ GET YOUR VARIABLE AND STORE IT HERE ################
}
catch {
    Write-Error $_.Exception.Message

    throw
}
