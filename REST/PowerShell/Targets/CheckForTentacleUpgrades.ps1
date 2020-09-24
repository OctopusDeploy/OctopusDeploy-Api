# Define working variables
$octopusURL = "https://your.octopus.app/api"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"

try {
    # Get space id
    $spaces = Invoke-RestMethod -Method Get -Uri "$octopusURL/spaces/all" -Headers $header -ErrorVariable octoError
    $space = $spaces | Where-Object { $_.Name -eq $spaceName }
    Write-Host "Using Space named $($space.Name) with id $($space.Id)"

    # Create space specific url
    $octopusSpaceUrl = "$octopusURL/$($space.Id)"

    # Get tentacles
    $targets = Invoke-RestMethod -Method Get -Uri "$octopusSpaceUrl/machines/all" -Headers $header -ErrorVariable octoError
    $workers = Invoke-RestMethod -Method Get -Uri "$octopusSpaceUrl/workers/all" -Headers $header -ErrorVariable octoError

    ($targets + $workers)
    | Where-Object { $_.Endpoint -and $_.Endpoint.TentacleVersionDetails }
    | ForEach-Object {
        Write-Host "Checking Tentacle version for $($_.Name)"
        $details = $_.Endpoint.TentacleVersionDetails

        Write-Host "`tTentacle status: $($_.HealthStatus)"
        Write-Host "`tCurrent version: $($details.Version)"
        Write-Host "`tUpgrade suggested: $($details.UpgradeSuggested)"
        Write-Host "`tUpgrade required: $($details.UpgradeRequired)"
    }
}
catch {
    Write-Host "There was an error during the request: $($octoError.Message)"
    exit
}