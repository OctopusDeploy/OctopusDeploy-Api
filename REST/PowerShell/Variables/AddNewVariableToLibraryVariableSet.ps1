$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$spaceName = "Default"
$libraryVariableSetName = "VariableSetName"

# Variable details to create
$VariableName = "Var-Name"
$VariableValue = "Var-Value"
$VariableIsSensitive = $False
$VariableType = "String"

# Get space
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -eq $spaceName }

Write-Host "Looking for library variable set '$libraryVariableSet'"
$LibraryvariableSets = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/libraryvariablesets?contentType=Variables" -Headers $header)
$LibraryVariableSet = $LibraryVariableSets.Items | Where-Object { $_.Name -eq $libraryVariableSetName }

if ($null -eq $libraryVariableSet) {
    Write-Warning "Library variable set not found with name '$libraryVariableSetName'."
    return
}

$LibraryVariableSetVariables = (Invoke-RestMethod -Method Get -Uri "$OctopusURL/api/$($Space.Id)/variables/$($LibraryVariableSet.VariableSetId)" -Headers $Header) 

$existingVariableMatches = @($LibraryVariableSetVariables.Variables | Where-Object { $_.Name -ieq $VariableName } )

if ($existingVariableMatches.Length -gt 0) {
    Write-Warning "Found existing variable. Exiting"
    return
}
else {
    $variable = @{
        Name        = $VariableName  
        Value       = $VariableValue
        Type        = $VariableType
        IsSensitive = $VariableIsSensitive
        # Add Scopes if you want to include those for your value.
        Scope       = @{ 
            # Environment = @(
            #     $environmentObj.Id
            #     )
        }
    }

    # Add new variable
    $LibraryVariableSetVariables.Variables += $variable
    # Update variable set
    Invoke-RestMethod -Method Put -Uri "$OctopusURL/api/$($Space.Id)/variables/$($LibraryVariableSetVariables.Id)" -Headers $Header -Body ($LibraryVariableSetVariables | ConvertTo-Json -Depth 10) | Out-Null
}
