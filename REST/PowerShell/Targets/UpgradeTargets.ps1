$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"
$machineNames = @("MyMachine")

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get machine list
$machines = @()
foreach ($machineName in $machineNames)
{
    # Get machine
    $machine = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/machines/all" -Headers $header) | Where-Object {$_.Name -eq $machineName}

    # Add to list
    $machines += $machine.Id
}

# Build json payload
$jsonPayload = @{
    Name = "Upgrade"
    Arguments = @{
        MachineIds = $machines
    }
    Description = "Upgrade machines"
    SpaceId = $space.Id
}

# Initiate upgrade
Invoke-RestMethod -Method Post -Uri "$octopusURL/api/$($space.Id)/tasks" -Headers $header -Body ($jsonPayload | ConvertTo-Json -Depth 10)