$octopusBaseURL = "https://your.octopus.app/api"
$octopusAPIKey = "API-yourapikey"
$headers = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$spaceNames = @("Default")

# Get space id
$spaces = Invoke-RestMethod -Method Get -Uri "$octopusBaseURL/spaces/all" -Headers $headers

foreach($spaceName in $spaceNames) {
    $space = $spaces | Where-Object { $_.Name -eq $spaceName }
    Write-Host "Using Space named $($space.Name) with id $($space.Id)"

    # Create space specific url
    $octopusSpaceUrl = "$octopusBaseURL/$($space.Id)"
    
    $targets = @()
    $workers = @()
    $targets = Invoke-RestMethod -Method Get -Uri "$octopusSpaceUrl/machines/all" -Headers $headers
    $workers = Invoke-RestMethod -Method Get -Uri "$octopusSpaceUrl/workers/all" -Headers $headers
    
    ($targets + $workers)
    | Where-Object { $_.Endpoint -and $_.Endpoint.CommunicationStyle -and $_.Endpoint.CommunicationStyle -eq "Ssh" -and $_.Endpoint.DotNetCorePlatform -eq $null }
    | ForEach-Object {
        Write-Host "SSH connection $($_.Name) ($($_.Id)) is still running Mono. Time to convert to .NET Core!"
    }
}
