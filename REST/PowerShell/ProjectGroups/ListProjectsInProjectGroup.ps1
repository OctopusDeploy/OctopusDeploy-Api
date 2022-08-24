$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"
$projectGroupName = "Your project Group name"

# Get space
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -eq $spaceName }

# Get project group
$projectGroups = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/projectgroups?partialName=$([uri]::EscapeDataString($projectGroupName))&skip=0&take=100" -Headers $header 
$projectGroup = $projectGroups.Items | Where-Object { $_.Name -eq $projectGroupName }

# Get projects
$projects = @()
$response = $null
do {
    $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/$($space.Id)/projectgroups/$($projectGroup.Id)/projects" }
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
    $projects += $response.Items
} while ($response.Links.'Page.Next')

Write-Host "Found $($projects.Count) projects in group $($projectGroupName)"