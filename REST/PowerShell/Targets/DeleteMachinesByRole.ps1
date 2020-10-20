$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://youroctourl/api"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"
$role = "MyRole"

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get machine list
$machines = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/machines/all" -Headers $header) | Where-Object {$role -in $_.Roles}

# Loop through list
foreach ($machine in $machines)
{
    # Remove machine
    Invoke-RestMethod -Method Delete -Uri "$octopusURL/api/$($space.Id)/machines/$($machine.Id)" -Headers $header
}