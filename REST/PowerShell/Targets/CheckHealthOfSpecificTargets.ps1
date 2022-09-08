#NOTE: This script does not RUN a health check, it only checks the current status of a machine from the latest health check.

# Define working variables
$OctopusURL = "https://"
$OctopusAPIKey = "API-"
$Header = @{ "X-Octopus-ApiKey" = $OctopusAPIKey }
$SpaceName = ""
$MachineIDs = @("Machines-501","Machines-991")   #comma separated list of machine ID's that you'd like to check the latest health status of.

$Space = (Invoke-RestMethod -Method Get -Uri "$OctopusURL/api/spaces/all" -Headers $Header) | Where-Object { $_.Name -eq $SpaceName }

Write-Host "`r`n"
foreach ($machineID in $MachineIDs){
    $Machine = (Invoke-RestMethod -Method Get -Uri "$OctopusURL/api/$($Space.id)/machines/$($machineID)" -Headers $Header)
    Write-Host "Machine: $($machine.Name)($($machineID)) `r`n| Disabled: $($machine.IsDisabled) `r`n| Health Status: $($machine.HealthStatus) `r`n| Status Summary: $($machine.StatusSummary)`r`n`r`n"
}
