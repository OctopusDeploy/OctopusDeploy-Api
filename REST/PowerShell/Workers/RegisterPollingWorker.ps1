$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-KEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"
$communicationsStyle = "TentacleActive" 
$hostName = "your-worker"
$workerPoolNames = @("Your worker pool")
$workerPoolIds = @()
$tentacleThumbprint = "TentacleThumbprint"
$tentacleIdentifier = "PollingTentacleIdentifier" # Must match value in Tentacle.config file on tentacle machine; ie poll://RandomCharacters

# Get space
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -eq $spaceName }

# Get workerpools
$workerpools = @()
$response = $null
do {
    $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/$($space.Id)/workerpools" }
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
    $workerpools += $response.Items
} while ($response.Links.'Page.Next')

foreach ($workerPoolName in $workerPoolNames)
{
    $workerPoolId = $workerpools | Where-Object { $_.Name -eq $workerPoolName } | Select-Object -ExpandProperty Id
    $workerPoolIds += $workerPoolId
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
    WorkerPoolIds = $workerPoolIds
    Name = $hostName
    Status = "Unknown"
    IsDisabled = $false
}

$jsonPayload

# Register new worker to space
Invoke-RestMethod -Method Post -Uri "$octopusURL/api/$($space.Id)/workers" -Headers $header -Body ($jsonPayload | ConvertTo-Json -Depth 10)