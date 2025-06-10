# Required parameters

## Instance Parameters
$octopusURL = "https://octopusURL"
$apiKey = "API-XXXX"
$spaceId = "Spaces-ID"
$variableSetId = "LibraryVariableSets-ID"

## Variable Parameters
$variableName = "Tenant Common Variable"
$defaultValue = "Tenant Common Value"
$controlType = "SingleLineText"

# Headers
$headers = @{
    "X-Octopus-ApiKey" = $apiKey
    "Content-Type" = "application/json; charset=utf-8"
}

# Get Var Set
$variableSet = Invoke-RestMethod -Method Get -uri "$octopusUrl/api/$($spaceId)/libraryvariablesets/$($variableSetId)" -Headers $headers


# Create New Template
$newTemplate = @"
{
    "DisplaySettings": {
        "Octopus.ControlType": "$($controlType)"
    },
    "Name": "$($variableName)",
    "DefaultValue": "$($defaultValue)"
}
"@

# Convert $newTemplate JSON string to an object
$newTemplateObj = $newTemplate | ConvertFrom-Json

# Append the new template object to existing templates array
$variableSet.Templates += $newTemplateObj

# Update var set with PUT method
Invoke-RestMethod -Method Put -Uri "$octopusUrl/api/$($spaceId)/libraryvariablesets/$($variableSetId)" -Body ($variableSet | ConvertTo-Json -Depth 10) -Headers $headers