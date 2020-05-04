Function Get-OctopusProject
{
    # Define parameters
    param(
        $OctopusServerUrl,
        $ApiKey,
        $ProjectName
    )

    # Call API to get all projects, then filter on name
    $octopusProject = Invoke-RestMethod -Method "get" -Uri "$OctopusServerUrl/api/projects/all" -Headers @{"X-Octopus-ApiKey"="$ApiKey"}

    # return the specific project
    return ($octopusProject | Where-Object {$_.Name -eq $ProjectName})
}

Function Get-OctopusProjectVariables
{
    # Define parameters
    param(
        $OctopusDeployProject,
        $OctopusServerUrl,
        $ApiKey
    )

    # Get reference to the variable list
    return (Invoke-RestMethod -Method "get" -Uri "$OctopusServerUrl/api/variables/$($OctopusDeployProject.VariableSetId)" -Headers @{"X-Octopus-ApiKey"="$ApiKey"})
}

    

Function Find-Variable{

    # Define parameters
    param(
        $VariableSet,
        $VariableName
    )
    $OutputVariable = "Variable not found based on name and current env"
    $EnvScopeValueSet = $False
   
    #Loop through the variables
    ForEach ($variable in $VariableSet.Variables){
    #Find matching varable by name
    if ($variable.Name -eq $VariableName){
    #Check if it has an environment scope. If it doesnt, and no EnvScopeValue has been found and set, set it.
    if (!$variable.Scope.Environment -and !$EnvScopeValueSet){

    $OutputVariable = $variable.Value

    }

    #If there is a scoped environment...
    else{
    #check to see if the name and current environment match. Set flag that env scope value found.
     if ($variable.Name -eq $VariableName -and $CurrentEnv -eq $variable.Scope.Environment){
           $OutputVariable = $variable.Value
           $EnvScopeValueSet = $True
        }
        }
    }
    
    }
    return $OutputVariable
}

### INPUT THESE VALUES ####

$OctopusServerUrl = ""  #PUT YOUR SERVER LOCATION HERE. (e.g. http://localhost)
$ApiKey = ""   #PUT YOUR API KEY HERE
$ProjectName = ""   #PUT THE NAME OF THE PROJECT THAT HOUSES THE VARIABLES HERE

#Gets the current environment that the deployment is running from. Hard code this if not running the code from in a deployment.
$CurrentEnv = $OctopusParameters["Octopus.Environment.Id"]




### INPUT THESE VALUES ####

try
{
    # Get reference to project
    $octopusProject = Get-OctopusProject -OctopusServerUrl $OctopusServerUrl -ApiKey $ApiKey -ProjectName $ProjectName

    # Get list of existing variables
    $octopusProjectVariables = Get-OctopusProjectVariables -OctopusDeployProject $octopusProject -OctopusServerUrl $OctopusServerUrl -ApiKey $ApiKey

    #### EXAMPLE ####
    #$tempValue = Find-Variable -VariableSet $octopusProjectVariables -VariableName "Test"
    #Write-Host $tempValue
  
    ##### GET YOUR VARIABLE AND STORE IT HERE #####
 

    ##### GET YOUR VARIABLE AND STORE IT HERE #####

    

}
catch
{
    Write-Error $_.Exception.Message

    throw
}
