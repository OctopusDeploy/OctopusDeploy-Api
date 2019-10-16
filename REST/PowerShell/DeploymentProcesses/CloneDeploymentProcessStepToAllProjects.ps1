$OctopusUrl = "" # Your URL
$ApiKey = "" # Your API Key
$sourceProjectName = "OctoFx-Database"
$stepNameToClone = "My New Script"
$spaceId = "Spaces-1"

$header = @{ "X-Octopus-ApiKey" = $ApiKey }

# The Name does a starts with search
$sourceProjectList = Invoke-RestMethod "$octopusUrl/api/$spaceId/projects?name=$sourceProjectName" -Headers $header
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

$destinationProjectList = Invoke-RestMethod "$octopusUrl/api/$spaceId/projects?skip=0&take=10000" -Headers $header
$updateHeader = @{
    "X-Octopus-ApiKey" = $ApiKey
    "x-octopus-user-agent" = "Api Script"
}

foreach ($project in $destinationProjectList.Items)
{
    if ($project.Id -ne $sourceProject.Id)
    {
        $deploymentProcessUrl = $OctopusUrl + $project.Links.DeploymentProcess
        $projectDeploymentProcess = Invoke-RestMethod $deploymentProcessUrl -Headers $header
        
        $projectDeploymentProcess.Steps += $stepToClone
        
        $deploymentProcessAsJson = $projectDeploymentProcess | ConvertTo-Json -Depth 8

        Invoke-WebRequest $deploymentProcessUrl -Headers $updateHeader -Method Put -Body $deploymentProcessAsJson -ContentType "application/json"        
    }
}