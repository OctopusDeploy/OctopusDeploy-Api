
# Script written to fix broken channel references on a deployment process
# https://github.com/OctopusDeploy/Issues/issues/5267

## CONFIG ##
$OctopusAPIkey = "" #Octopus API Key
$OctopusURL = "" #Octopus root url
$ProjectName = "" #Name of the project

## PROCESS ##

$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$allprojects = (Invoke-WebRequest $OctopusURL/api/projects/all -Headers $header).content | ConvertFrom-Json 
$allchannels = (Invoke-WebRequest $OctopusURL/api/channels/all -Headers $header).content | ConvertFrom-Json 

$project = $allprojects | where-object { $_.name -eq $ProjectName }

if ($project -ne $null) {
    $deploymentProcessUrl = $project.Links.DeploymentProcess
    $deploymentProcess = (Invoke-WebRequest "$($OctopusURL)$($deploymentProcessUrl)" -Headers $header).content | ConvertFrom-Json

    $channelsInProject = $allchannels | where-object { $_.ProjectId -eq $project.Id }

    foreach ($step in $deploymentProcess.Steps) {
        foreach ($action in $step.Actions) {
            # filter the channels on the action to only the channels that exist
            $action.Channels = @($action.Channels | where-object { $channelId = $_; $channelsInProject | where-object { $_.Id -eq $channelId }})
        }
    }

    $deploymentProcessJson = $deploymentProcess | ConvertTo-Json -depth 100

    Invoke-WebRequest "$($OctopusURL)$($deploymentProcessUrl)" -Method Put -Headers $header -Body $deploymentProcessJson
} else {
    Write-Error "Project [$ProjectName] not found in $OctopusURL"
}
