$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "http://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"
$Description = "Health check started from Powershell script"
$TimeOutAfterMinutes = 5
$MachineTimeoutAfterMinutes = 5

# Choose an Environment, a set of machine names, or both.
$EnvironmentName = "Development" # Leave blank to check all environments
$MachineNames = @() # Leave blank to check all machines

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) |
Where-Object { $_.Name -eq $spaceName }
if (-not $space) {
    throw "Space '$spaceName' not found"
}

# Get EnvironmentId
$EnvironmentID = $null
if (-not [string]::IsNullOrWhiteSpace($EnvironmentName)) {
    $EnvironmentID = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/environments/all" -Headers $header) |
    Where-Object { $_.Name -eq $EnvironmentName } |
    Select-Object -ExpandProperty Id -First 1
    if (-not $EnvironmentID) {
        throw "Environment '$EnvironmentName' not found in space '$($space.Name)'"
    }
}

# Get MachineIds
$MachineIds = @()
if ($MachineNames.Count -gt 0) {
    $MachineIds = @((Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/machines/all" -Headers $header) |
        Where-Object { $MachineNames -contains $_.Name } |
        Select-Object -ExpandProperty Id)
    if ($MachineIds.Count -ne $MachineNames.Count) {
        throw "One or more machines not found in space '$($space.Name)'"
    }
}

# Create json payload
$jsonPayload = @{
    SpaceId     = "$($space.Id)"
    Name        = "Health"
    Description = $Description
    Arguments   = @{
        Timeout        = "$([TimeSpan]::FromMinutes($TimeOutAfterMinutes))"
        MachineTimeout = "$([TimeSpan]::FromMinutes($MachineTimeoutAfterMinutes))"
        EnvironmentId  = $EnvironmentID
        MachineIds     = $MachineIds
    }
}

# Create health check task
Invoke-RestMethod -Method Post -Uri "$octopusURL/api/$($space.Id)/tasks" -Body ($jsonPayload | ConvertTo-Json -Depth 10) -Headers $header
