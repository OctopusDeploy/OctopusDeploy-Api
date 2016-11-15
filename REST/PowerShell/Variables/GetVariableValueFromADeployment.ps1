##CONFIG
$OctopusURL = "" #Octopus URL
$OctopusAPIKey = "" #Octopus API Key

$DeploymentID = "" #ID of the deployment you want to get the variable from. E.g. Deployments-41
$VariableName = "" #Variable name

##PROCESS##
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$variable = ((invoke-webrequest $OctopusURL/api/variables/variableset-$DeploymentID -Headers $header).content | ConvertFrom-Json).variables | ?{$_.name -eq $VariableName}

$variable.value