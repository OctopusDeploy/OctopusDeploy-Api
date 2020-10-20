$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"
$machineName = "MyMachine"
$targetRole = "MyRole"

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get machine
$machine = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/machines/all" -Headers $header) | Where-Object {$_.Name -eq $machineName}

# Add target role
$machine.roles += ($targetRole)

Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/machines/$($machine.Id)" -Body ($machine | ConvertTo-Json -Depth 10) -Headers $header