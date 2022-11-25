##CONFIG##
$OctopusAPIkey = "" #Your Octopus API Key
$OctopusURL = "" #Your Octopus Server root URL
$MaintanceModeValue = "true" #True or false to enable/disable mainteancemode
$jsonPayload = @{
    IsInMaintenanceMode=$MaintanceModeValue
}

##PROCESS##
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$MaintenanceConfig = Invoke-RestMethod $OctopusURL/api/maintenanceconfiguration -Method PUT -Body ($jsonPayload | ConvertTo-Json -Depth 10) -Headers $header
Write-host $MaintenanceConfig
