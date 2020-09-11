# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"
$feedName = "nuget.org"

# Change property
$newFeedName = "nuget.org feed"

try
{
    # Get space
    $space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

    # Get feed
    $feed = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/feeds/all" -Headers $header) | Where-Object {$_.Name -eq $feedName}
    
    # Change feed name
    $feed.Name = $newFeedName
    
    # Update feed in Octopus
    Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/feeds/$($feed.Id)" -Body ($feed | ConvertTo-Json -Depth 10) -Headers $header -Method Put
}
catch
{
    Write-Host $_.Exception.Message
}