$ErrorActionPreference = "Stop";
# Define working variables
$octopusURL = "http://localhost/"
$octopusAPIKey = ""
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

# Specify the Space to search in
$spaceName = ""

# Library Variable Set
$libraryVariableSetName = ""

# Variable name to search
$VariableName = "test"

# Variable name to search
$VariableValue = "wibble"

$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

Write-Host "Looking for library variable set '$libraryVariableSet'"
$LibraryvariableSets = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/libraryvariablesets?contentType=Variables" -Headers $header)
$LibraryVariableSet = $LibraryVariableSets.Items | Where-Object { $_.Name -eq $libraryVariableSetName }

if ($null -eq $libraryVariableSet) {
    Write-Warning "Library variable set not found with name '$$libraryVariableSetName'."
    exit
}


$LibraryVariableSetVariables = (Invoke-RestMethod -Method Get -Uri "$OctopusURL/api/$($Space.Id)/variables/$($LibraryVariableSet.VariableSetId)" -Headers $Header) 

for($i=0; $i -lt $LibraryVariableSetVariables.Variables.Length; $i++) {
    $existingVariable = $LibraryVariableSetVariables.Variables[$i];
    if($existingVariable.Name -eq $VariableName) {
        Write-Host "Found existing variable, updating its value"
        $existingVariable.Value = $VariableValue
    }
}

$existingVariable = $LibraryVariableSetVariables.Variables  | Where-Object {$_.name -eq $VariableName} | Select-Object -First 1 

$UpdatedLibraryVariableSet = Invoke-RestMethod -Method Put -Uri "$OctopusURL/api/$($Space.Id)/variables/$($LibraryVariableSetVariables.Id)" -Headers $Header -Body ($LibraryVariableSetVariables | ConvertTo-Json -Depth 10)   

