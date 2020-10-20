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
$EnvironmentName = "Development"
$MachineNames = @()

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get EnvironmentId
$EnvironmentID = $null
if([string]::IsNullOrWhiteSpace($EnvironmentName) -eq $False) 
{
    $EnvironmentID += (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/environments/all" -Headers $header) | Where-Object {$_.Name -eq $EnvironmentName} | Select-Object -ExpandProperty Id -First 1
}

# Get MachineIds
$MachineIds = $null
if($MachineNames.Count -gt 0)
{
    $MachineIds = $EnvironmentID += (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/machines/all" -Headers $header) | Where-Object {$_.Name -eq $EnvironmentName} | Select-Object -ExpandProperty Id -Join ", "
}

# Create json payload
$jsonPayload = @{
    SpaceId = "$($space.Id)"
    Name = "Health"
    Description = $Description
    Arguments = @{
        Timeout = "$([TimeSpan]::FromMinutes($TimeOutAfterMinutes))"
        MachineTimeout = "$([TimeSpan]::FromMinutes($MachineTimeoutAfterMinutes))"
        EnvironmentId = $EnvironmentID
        MachineIds = $MachineIds
    }
}

# Create health check task
Invoke-RestMethod -Method Post -Uri "$octopusURL/api/$($space.Id)/tasks" -Body ($jsonPayload | ConvertTo-Json -Depth 10) -Headers $header