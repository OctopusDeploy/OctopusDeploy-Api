##CONFIG##
$OctopusAPIkey = "" #Octopus API Key
$OctopusURL = "" #Octopus URL

##PROCESS##
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$allMachines = (Invoke-WebRequest $OctopusURL/api/machines/all -Method Get -Headers $header -UseBasicParsing).content | ConvertFrom-Json
$healthyMachines = $allMachines | ? {$_.HealthStatus -eq "Healthy"}

$healthyMachines | %{ "Machine $($_.Name): UpgradeSuggested=$($_.Endpoint.TentacleVersionDetails.UpgradeSuggested), UpgradeRequired=$($_.Endpoint.TentacleVersionDetails.UpgradeRequired)"} 
