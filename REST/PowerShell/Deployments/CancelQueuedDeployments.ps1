$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get tasks
$tasks = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/tasks" -Headers $header).Items | Where-Object {$_.State -eq "Queued" -and $_.HasBeenPickedUpByProcessor -eq $false -and $_.Name -eq "Deploy"}

# Loop through tasks
foreach ($task in $tasks)
{
    # Cancel task
    Invoke-RestMethod -Method Post -Uri "$octopusURL/api/$($space.Id)/tasks/$($task.Id)/cancel" -Headers $header
}