$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "http://octotemp"
$octopusAPIKey = "API-APIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$eventDate = "9/9/2020"

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get events
$events = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/events" -Headers $header).Items | Where-Object {([datetime]$_.Occurred -ge [datetime]$eventDate) -and ([datetime]$_.Occurred -le ([datetime]$eventDate).AddDays(1).AddSeconds(-1))}

# Display events
foreach ($event in $events)
{
    $event
}