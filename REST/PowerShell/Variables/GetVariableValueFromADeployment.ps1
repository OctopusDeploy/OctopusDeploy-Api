##CONFIG
$OctopusURL = "" #Octopus URL
$OctopusAPIKey = "" #Octopus API Key

$DeploymentID = "" #ID of the deployment you want to get the variable from. E.g. Deployments-41
$VariableName = "" #Variable name

##PROCESS##
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$variable = (Invoke-RestMethod -Method GET -Uri "$OctopusURL/api/variables/variableset-$DeploymentID" -Headers $header).variables | Where-Object { $_.name -eq $VariableName }

$variable.value
