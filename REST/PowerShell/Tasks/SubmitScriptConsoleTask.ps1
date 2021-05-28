$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://octopus-url/"
$octopusAPIKey = "API-XXX"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$machineNames = @("server-01")

$spaceName = "Default"
# Get space
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -eq $spaceName }
$spaceId = $space.Id

# Get machine 
$machineList = New-Object System.Collections.ArrayList

foreach ($machineName in $machineNames) {
    $machine = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/machines/all" -Headers $header) | Where-Object {$_.Name -eq $machineName}
    if (!$machine){
        Write-Warning "Machine not found $($machineName)"
    } else {
        $machineList.Add($machine.Id)
    }
}

$script = 'echo \"hello\"'

$arguments = @{    
    MachineIds = $machineList
    TargetType = "Machines"
    Syntax = "Bash"
    ScriptBody = $script
}

# Create runbook Payload
$scriptTaskBody = (@{
    Name = "AdHocScript"
    Description = "Script run from management console"
    Arguments = $arguments
    SpaceId = $spaceId
}) | ConvertTo-Json -Depth 10

# Run the runbook 
Invoke-RestMethod -Method "POST" "$($octopusURL)/api/tasks" -body $scriptTaskBody -Headers $header -ContentType "application/json"
