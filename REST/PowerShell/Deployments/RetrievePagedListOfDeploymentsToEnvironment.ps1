$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-KEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

# Space name
$spaceName = "Default"

# Environment name
$environmentName = "Development"

# Get space
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -eq $spaceName }

# Get environment
$environments = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/environments?partialName=$([uri]::EscapeDataString($environmentName))&skip=0&take=100" -Headers $header 
$environment = $environments.Items | Where-Object { $_.Name -eq $environmentName } | Select-Object -First 1

# Get deployments to environment
$deployments = @()
$response = $null
do {
    $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/$($space.Id)/deployments?environments=$($environment.Id)" }
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
    Write-Output "Found $($response.Items.Length) deployments.";
    $deployments += $response.Items
} while ($response.Links.'Page.Next')

Write-Output "Retrieved $($deployments.Count) deployments to environment $($environmentName)"