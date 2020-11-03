# Define Octopus variables
$octopusURL = "https://youroctopusserver"
$octopusAPIKey = "API-KEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get machine details
$machines = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/machines" -Headers $header).Items

foreach ($machine in $machines) {
    $machineTasks = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/machines/$($machine.Id)/tasks" -Headers $header).Items
    if ($machineTasks.Count -gt 0) {
        $machine | Add-Member LastDeployment $machineTasks[0].Description
        $machine | Add-Member LastDeploymentQueueTime $machineTasks[0].QueueTime
    }
}

$machines | Select-Object Id, Name, Status, LastDeployment, LastDeploymentQueueTime | Format-Table
