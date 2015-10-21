$octopusAPIKey = ""
$octopusURL = ""
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

#To get the deployment ID, click on the deployment and you'll reach a URL similar to this: http://localhost/app#/projects/Projects-2/releases/1.0.142/deployments/Deployments-744
#The deployment ID in that case is Deployments-744
$deploymentID = ""

Invoke-RestMethod "$octopusURL/api/deployments/$deploymentID" -Method Delete -Headers $header