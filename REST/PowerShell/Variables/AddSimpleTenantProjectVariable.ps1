# Required parameters

## Instance Parameters
$octopusURL = "https://octopusUrl"
$apiKey = "API-XXXX"
$spaceId = "Spaces-ID"
$projectId = "Projects-ID"

## Variable Parameters
$variableName = "Tenant Project Variable"
$defaultValue = "Tenant Project Value"
$controlType = "SingleLineText"

# Headers
$headers = @{
    "X-Octopus-ApiKey" = $apiKey
    "Content-Type" = "application/json; charset=utf-8"
}

# Get Project
$project = Invoke-RestMethod -Method Get -uri "$octopusUrl/api/$($spaceId)/projects/$($projectId)" -Headers $headers


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
$project.Templates += $newTemplateObj

# Update project with PUT method
Invoke-RestMethod -Method Put -Uri "$octopusUrl/api/$($spaceId)/projects/$($projectId)" -Body ($project | ConvertTo-Json -Depth 10) -Headers $headers