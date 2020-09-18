# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"
$hostName = "MyHost"
$tentaclePort = "10933"
$environmentNames = @("Development", "Production")
$roles = @("MyRole")

try
{
    # Get space
    $space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

    # Get environment Ids
    $environments = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/environments/all" -Headers $header) | Where-Object {$environmentNames -contains $_.Name}
    foreach ($environment in $environments)
    {
        $environmentIds += $environment.Id
    }

    # Discover new target
    $newTarget = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/machines/discover?host=$hostName&port=$tentaclePort&type=TentaclePassive" -Headers $header

    # Create JSON payload
    $jsonPayload = @{
        Endpoint = @{
            CommunicationStyle = $newTarget.Endpoint.CommunicationStyle
            Thumbprint = $newTarget.Endpoint.Thumbprint
            Uri = $newTarget.Endpoint.Uri
        }
        EnvironmentIds = $environmentIds
        Name = $newTarget.Name
        Roles = $roles
        Status = "Unknown"
        IsDisabled = $false
    }

    # Register new target to space
    Invoke-RestMethod -Method Post -Uri "$octopusURL/api/$($space.Id)/machines" -Headers $header -Body ($jsonPayload | ConvertTo-Json -Depth 10)
}
catch
{
    Write-Host $_.Exception.Message
}