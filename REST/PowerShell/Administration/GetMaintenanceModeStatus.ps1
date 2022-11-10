##CONFIG##
$OctopusAPIkey = "" #Your Octopus API Key
$OctopusURL = "" #Your Octopus Server root URL


##PROCESS##
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$MaintenanceConfig = ((Invoke-WebRequest $OctopusURL/api/maintenanceconfiguration -Method GET -Headers $header).content | ConvertFrom-Json).IsInMaintenanceMode
Write-host $MaintenanceConfig