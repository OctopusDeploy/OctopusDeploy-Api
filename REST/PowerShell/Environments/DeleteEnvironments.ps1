$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-YOURKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$spaceName = "API Playground"
$deleteAllEnvironments = $False
$environmentNames = @("Development", "Test", "Staging", "Production")

# Get space
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -eq $spaceName }

if($deleteAllEnvironments -eq $True) {
    Write-Warning "Querying all environments in Space: $spaceName"
    $environmentsResource = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/environments?skip=0&take=100000" -Headers $header
    $environmentNames = $environmentsResource.Items | Select-Object "$($_.Name)"
}

foreach ($environment in $environmentNames) {
    # Check to see if environment exists
    $environments = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/environments?partialName=$([uri]::EscapeDataString($environment))&skip=0&take=100" -Headers $header
    $existingEnvironment = $environments.Items | Where-Object { $_.Name -eq $environment }

    if($null -eq $existingEnvironment) {
        Write-Host "Environment '$environment' doesnt exists. Nothing to delete :)"
    }
    else {
        Write-Host "Deleting environment '$environment'"
        Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/environments/$($existingEnvironment.Id)" -Headers $header -Method Delete -Body $body 
    }
}
