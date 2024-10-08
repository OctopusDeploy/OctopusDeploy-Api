$OctopusUrl = "https://octopusURL" # Your URL
$ApiKey = "API-KEY" # Your API Key
$sourceProjectName = ""
$destinationProjectName = ""
$stepNameToClone = ""
$exportSpaceId = ""
$destinationSpaceId = ""

$header = @{ "X-Octopus-ApiKey" = $ApiKey }

# The Name does a starts with search
$sourceProjectList = Invoke-RestMethod "$octopusUrl/api/$exportSpaceId/projects?name=$sourceProjectName" -Headers $header
$sourceProject = $sourceProjectList.Items | Where {$_.Name -eq $sourceProjectName}

$deploymentProcessUrl = $OctopusUrl + $sourceProject.Links.DeploymentProcess
$deploymentProcess = Invoke-RestMethod $deploymentProcessUrl -Headers $header

$stepToClone = $deploymentProcess.Steps | where {$_.Name -eq $stepNameToClone}
$stepToClone.Id = ""
foreach ($action in $stepToClone.Actions)
{
    $action.Id = ""
}

Write-Host $stepToClone

$destinationProjectList = Invoke-RestMethod "$octopusUrl/api/$destinationSpaceId/projects?skip=0&take=10000" -Headers $header
$destinationProject = $destinationProjectList.Items | Where {$_.Name -eq $destinationProjectName}

# If different permissions are required on the import space, update the API key value here to the key used for the import space.
$updateHeader = @{
    "X-Octopus-ApiKey" = $ApiKey
    "x-octopus-user-agent" = "Api Script"
}

$deploymentProcessUrl = $OctopusUrl + $destinationProject.Links.DeploymentProcess
$projectDeploymentProcess = Invoke-RestMethod $deploymentProcessUrl -Headers $header

$projectDeploymentProcess.Steps += $stepToClone

$deploymentProcessAsJson = $projectDeploymentProcess | ConvertTo-Json -Depth 8

Invoke-WebRequest $deploymentProcessUrl -Headers $updateHeader -Method Put -Body $deploymentProcessAsJson -ContentType "application/json"        
