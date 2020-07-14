#This script is for all pre-Spaces Octopus servers. This will run for the default space only for versions with Spaces

$OctopusUrl = "" # Octopus URL
$APIKey = "" # API Key that can read the number of machines

# Authenticating to the API
$header = @{ "X-Octopus-ApiKey" = $APIKey }

# Getting the number of active deployment targets
Write-Host "Getting list of machines: $OctopusUrl/api/machines?skip=0&take=100000"
$Machines = (Invoke-RestMethod "$OctopusUrl/api/machines?skip=0&take=100000" -Headers $header | Select-Object -ExpandProperty TotalResults)
Write-Host "There are $Machines Deployment Targets in this Octopus Instance"