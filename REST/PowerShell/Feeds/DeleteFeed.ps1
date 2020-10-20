$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"
$feedName = "nuget.org"

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get feedID
$feed = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/feeds/all" -Headers $header) | Where-Object {$_.Name -eq $feedName}
$feedID = $feed.Id

# Delete Feed
Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/feeds/$feedID" -Headers $header -Method Delete