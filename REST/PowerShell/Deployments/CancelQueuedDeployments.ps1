$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

$canContinue = $true

while ($canContinue -eq $true)
{
    # Get tasks
    $tasks = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/tasks?States=Queued&Name=Deploy" -Headers $header

    # Loop through tasks
    foreach ($task in $tasks.Items)
    {
        # Cancel task
        Invoke-RestMethod -Method Post -Uri "$octopusURL/api/$($space.Id)/tasks/$($task.Id)/cancel" -Headers $header
    }

    $canContinue = $tasks.NumberOfPages -gt 1
}