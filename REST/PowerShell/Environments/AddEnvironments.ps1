$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://youroctopus.octopus.app"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$spaceName = "Default"
$environments = @("Development", "Test", "Staging", "Production")

# Get space
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -eq $spaceName }

foreach ($environment in $environments) {
    
    # Check to see if environment exists
    $environments = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/environments?partialName=$([uri]::EscapeDataString($environment))&skip=0&take=100" -Headers $header
    $existingEnvironment = $environments.Items | Where-Object { $_.Name -eq $environment }

    if($null -ne $existingEnvironment) {
        Write-Host "Environment '$environment' already exists. Nothing to create :)"
    }
    else {

        $body = @{
            Name = $environment
        } | ConvertTo-Json

        Write-Host "Creating environment '$environment'"
        $response = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/environments" -Headers $header -Method Post -Body $body 
        Write-Host "EnvironmentId: $($response.Id)"
    }
}