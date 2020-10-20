$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get all feeds
$feeds = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/feeds/all" -Headers $header)

# Enumerate each feed
foreach($feed in $feeds)
{
    $feed
}