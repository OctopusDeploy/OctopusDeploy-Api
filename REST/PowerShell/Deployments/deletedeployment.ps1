$octopusAPIKey = ""
$octopusURL = ""
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$deploymentID = ""

Invoke-RestMethod "$env:octopusURL/api/deployments/$deploymentID" -Method Delete -Headers $header