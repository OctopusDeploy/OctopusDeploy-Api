# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$spaceName = "New Space"

try {
    Write-Host "Getting space '$spaceName'"
    $spaces = (Invoke-WebRequest $octopusURL/api/spaces?take=21000 -Headers $header -Method Get -ErrorVariable octoError).Content | ConvertFrom-Json

    $space = $spaces.Items | Where-Object Name -eq $spaceName

    if ($null -eq $space) {
        Write-Host "Could not find space with name '$spaceName'"
        exit
    }

    $space.TaskQueueStopped = $true
    $body = $space | ConvertTo-Json

    Write-Host "Stopping space task queue"
    (Invoke-WebRequest $octopusURL/$($space.Links.Self) -Headers $header -Method PUT -Body $body -ErrorVariable octoError) | Out-Null

    Write-Host "Deleting space"
    (Invoke-WebRequest $octopusURL/$($space.Links.Self) -Headers $header -Method DELETE -ErrorVariable octoError) | Out-Null

    Write-Host "Action Complete"
}
catch {
    Write-Host "There was an error during the request: $($octoError.Message)"
    exit
}