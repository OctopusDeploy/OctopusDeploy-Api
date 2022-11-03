# Define your working variables
$OctopusUrl = "https://yourOctopusURL"
$APIKey = "API-xxx"
$header = @{ "X-Octopus-ApiKey" = $APIKey }
$spaceId = "Spaces-xx"
$environmentIdToRemove = "Environments-xxx"

$Machines = (Invoke-RestMethod "$OctopusUrl/api/$spaceId/machines?skip=0&take=100000" -Headers $header)

$machinesToCheck = @()
$modifiedMachines = @()

foreach ($machine in $machines.Items) {
    $environmentIds = @()
    if ($machine.EnvironmentIds -contains $environmentIdToRemove) {
        if (($machine.EnvironmentIds).Count -gt 1) {
            foreach ($environment in $machine.EnvironmentIds) {
                if ($environment -ne $environmentIdToRemove) {
                    $environmentIds += $environment
                }
            }
            
            $machine.EnvironmentIds = $environmentIds
            $modifiedMachines += $machine.Name
            Invoke-RestMethod -Method PUT "$OctopusUrl/api/machines/$($machine.Id)" -Headers $header -Body ($machine | ConvertTo-Json -Depth 10)
        }
        else {
            $machinesToCheck += $machine.Name
        }
    }
    
}

Write-Host "Modified machines list: " $modifiedMachines
Write-Host "Machines to manually check: " $machinesToCheck
