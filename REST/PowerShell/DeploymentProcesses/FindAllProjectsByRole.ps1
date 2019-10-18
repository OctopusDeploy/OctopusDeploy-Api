$OctopusUrl = "" # Your URL
$ApiKey = "" # Your API Key
$roleName = "FileBackup"
$header = @{ "X-Octopus-ApiKey" = $ApiKey }

$projectList = Invoke-RestMethod "$octopusUrl/api/$spaceId/projects?skip=0&take=10000" -Headers $header
$projectsWithRoles = @()

foreach ($project in $projectList.Items)
{
    $deploymentProcessUrl = $OctopusUrl + $project.Links.DeploymentProcess
    $projectDeploymentProcess = Invoke-RestMethod $deploymentProcessUrl -Headers $header
    
    foreach ($step in $projectDeploymentProcess.Steps)
    {        
        if ($step.Properties.'Octopus.Action.TargetRoles' -contains $roleName)
        {
            $projectsWithRoles += $project.Name
            break
        }
    } 
}

Write-Host "The following projects have $roleName"
foreach ($projectName in $projectsWithRoles)
{
    Write-Host $projectName
}