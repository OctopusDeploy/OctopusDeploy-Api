$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"
$communicationsStyle = "TentacleActive" # Listening mode
$hostName = "MyHost"
$environmentNames = @("Development", "Production")
$roles = @("MyRole")
$environmentIds = @()
$tentacleThumbprint = "TentacleThumbprint"
$tentacleIdentifier = "PollingTentacleIdentifier" # Must match value in Tentacle.config file on tentacle machine; ie poll://RandomCharacters

# Get space
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -eq $spaceName }

# Get environment Ids
$environments = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/environments/all" -Headers $header) | Where-Object {$environmentNames -contains $_.Name}
foreach ($environment in $environments)
{
    $environmentIds += $environment.Id
}

# Create unique URI for tentacle
$tentacleURI = "poll://$tentacleIdentifier"

# Create JSON payload
$jsonPayload = @{
    Endpoint = @{
        CommunicationStyle = $communicationsStyle
        Thumbprint = $tentacleThumbprint
        Uri = $tentacleURI
    }
    EnvironmentIds = $environmentIds
    Name = $hostName
    Roles = $roles
    Status = "Unknown"
    IsDisabled = $false
}

$jsonPayload

# Register new target to space
Invoke-RestMethod -Method Post -Uri "$octopusURL/api/$($space.Id)/machines" -Headers $header -Body ($jsonPayload | ConvertTo-Json -Depth 10)