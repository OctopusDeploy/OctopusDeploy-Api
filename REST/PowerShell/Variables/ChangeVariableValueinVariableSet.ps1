#Allows HTTPS connections
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$VarSetName = "YourVariableSetName"           #The exact name of the Variable Set you are trying to change a variable within. Not needed if you know ID
$VarSetID = ""                                #Leave blank if you dont know your variable set ID

$VariableName = "YourVariableName"            #The name of the variable you are trying to change the value of
$VariableValue = "YourValue"                  #New value of Variable
$VariableEnvName = "YourEnvironment"          #Scope of a variable to a environment, leave blank to scope to all
$OverrideMultipleEnv = $False                 #True will replace Value for environments will multiple scopes i.e. if a environment is part of 2 scopes it will replace both 
                                              #False will cause an error if the environment is shared with more than value or if multiple scopes have the environment

$OctopusSite = "https://your.site.com"        #Your Octopus site name
$octoapikey = "API-................"          #Your Octopus API Key


#If the Library ID was not provided it will try and find one instance of it using the Library Name
if (!$VarSetID) {
    try {
        $VarSets = Invoke-RestMethod "$OctopusSite/api/libraryvariablesets" -Method Get -Headers @{"X-Octopus-ApiKey" = $octoapikey} -ContentType "application/json"
        $VarSetID = ($VarSets.Items | Where-Object { $_.Name -ieq $VarSetName }).ID
        if (($VarSetID).count -lt 1) {
            Write-Error "Did not find any entries matching that Library name"
            return -1
        }
        elseif (($VarSetID).count -gt 1) {
            Write-Error "Found more than one entry matching that Library name"
            return -1
        }
    }
    catch {
        Write-Error $_
        Return -1
    }
}

#Pulls down all variables from Library ID. Note sensitive values are not exposed
try {
    $Variables = Invoke-RestMethod "$OctopusSite/api/variables/variableset-$VarSetID" -Method Get -Headers @{"X-Octopus-ApiKey" = $octoapikey} -ContentType "application/json"
}
catch {
    Write-Error $_
    Return -1
}

#Finds the Environment ID if Environment Name is provided
if ($VariableEnvName) {
    $VariableEnvID = ($Variables.ScopeValues.Environments | Where-Object { $_.Name -ieq $VariableEnvName}).ID
    if (($VariableEnvID).count -lt 1) {
        Write-Error "Did not find any entries matching that environment name"
        return -1
    }
    elseif (($VariableEnvID).count -gt 1) {
        Write-Error "Found more than one entry matching that environment name"
        return -1
    }
}

#Finds the Variable name within the Library. This will error out if it cant find the environment or finds too many environments without the override.
$ScopesFound = 0
$Variables.Variables | ForEach-Object {if (($_.Name -ieq $VariableName) -and (($_.Scope.Environment -ieq $VariableEnvID) -or ((!$_.Scope) -and (!$VariableEnvName)))) {
        if ((($_.Scope.Environment).count -gt 1) -and (!$OverrideMultipleEnv)) {
            Write-Error "Found more than one environment and overwrite was not set to true"
            break
        }
        $_.value = $VariableValue
        $ScopesFound++
    }
}

#This is making sure something was found
if ($ScopesFound -lt 1) {
    Write-Error "Did not find any variables with that name and scope"
    return -1
}
#This is to make sure multiple variables were not found unless override was true
elseif (($ScopesFound -gt 1) -and (!$OverrideMultipleEnv)) {
    Write-Error "Found more than one scope for that variable name and override was not true"
    return -1
}

#Creates a payload to upload back to octopus
$VariablePayload = ConvertTo-Json $Variables -Depth 50

#This imports the new values into octopus. If a value is sensitive it will still be sensitive once uploaded
try {
    Invoke-RestMethod "$OctopusSite/api/variables/variableset-$VarSetID" -Method Put -ContentType "application/json" -Headers @{"X-Octopus-ApiKey" = $octoapikey} -Body $VariablePayload
}
catch {
    Write-Error $_
    Return -1
}
