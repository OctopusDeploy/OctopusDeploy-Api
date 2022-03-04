$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://mysite.octopus.app"
$octopusAPIKey = "API-MYAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"
$machineName = "mymachinename"
$machineProxyName = "myproxyname"

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get machine list
$machine = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/machines/all" -Headers $header) | Where-Object {$_.Name -eq $machineName}

# Get specified proxy ID
$machineProxy = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/proxies/all" -Headers $header) | Where-Object { $_.Name -eq $machineProxyName } 

# Update machine object
$machine.Endpoint.ProxyId = $machineProxy.Id
Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/machines/$($machine.Id)" -Body ($machine | ConvertTo-Json -Depth 10) -Headers $header