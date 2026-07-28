$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "http://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"
$description = "Health check started from Powershell script"
$timeoutAfterMinutes = 5
$machineTimeoutAfterMinutes = 5

# Choose an Environment, a set of machine names, or both.
$environmentName = "Development" # Leave blank to check all environments
$machineNames = @("TestMachine1", "TestMachine2") # Leave blank to check all machines

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) |
Where-Object { $_.Name -eq $spaceName }
if (-not $space) {
    throw "Space '$spaceName' not found"
}

# Get EnvironmentId
$environmentId = $null
if (-not [string]::IsNullOrWhiteSpace($environmentName)) {
    $environmentId = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/environments/all" -Headers $header) |
    Where-Object { $_.Name -eq $environmentName } |
    Select-Object -ExpandProperty Id -First 1
    if (-not $environmentId) {
        throw "Environment '$environmentName' not found in space '$($space.Name)'"
    }
}

# Get MachineIds
$machineIds = @()
if ($machineNames.Count -gt 0) {
    $machineIds = @((Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/machines/all" -Headers $header) |
        Where-Object { $machineNames -contains $_.Name } |
        Select-Object -ExpandProperty Id)
    if ($machineIds.Count -ne $machineNames.Count) {
        throw "One or more machines not found in space '$($space.Name)'"
    }
}

# Create json payload
$jsonPayload = @{
    SpaceId     = "$($space.Id)"
    Name        = "Health"
    Description = $description
    Arguments   = @{
        Timeout        = "$([TimeSpan]::FromMinutes($timeoutAfterMinutes))"
        MachineTimeout = "$([TimeSpan]::FromMinutes($machineTimeoutAfterMinutes))"
        EnvironmentId  = $environmentId
        MachineIds     = $machineIds
    }
}

# Create health check task
Invoke-RestMethod -Method Post -Uri "$octopusURL/api/$($space.Id)/tasks" -Body ($jsonPayload | ConvertTo-Json -Depth 10) -Headers $header
