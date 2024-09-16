
$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app/"
$octopusAPIKey = "API-KEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"
$projectName = "Your-Project-Name"

$octopusURI = $octopusURL

$setting = "EnvironmentDefault"

# Get space
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -eq $spaceName }
$defaultSpaceId = $space.Id

$project = (Invoke-RestMethod -Uri "$octopusURI/api/$defaultSpaceId/projects/all" -Method GET -Headers $header) | Where-Object { $_.Name -eq $projectName }
if (!$project) {
    Write-Warning "Can't find $projectName, skipping this project."
    return
}

# Get project deployment settings
$projectDeploymentSettings = Invoke-RestMethod -Uri "$octopusURI/api/$defaultSpaceId/projects/$($project.id)/deploymentsettings" -Method GET -Headers $header
if ($null -eq $projectDeploymentSettings) {
    Write-Warning "Can't find deployment settings for $projectName, skipping this project."
    return
}
    
if ($setting -eq $projectDeploymentSettings.DefaultGuidedFailureMode) {
    Write-Host "$projectname guided failure setting is already set to: $setting... Skipping"
    return
}
$projectDeploymentSettings.DefaultGuidedFailureMode = $setting
$jsonBody = $projectDeploymentSettings | ConvertTo-Json -Depth 12

try {
    Invoke-RestMethod -Uri "$octopusURI/api/$defaultSpaceId/projects/$($project.id)/deploymentsettings" -Method PUT -Headers $header -Body $jsonBody -ContentType "application/json"
    Write-Host "Successfully updated $projectname"
}
catch {
    Write-Error $_
}
