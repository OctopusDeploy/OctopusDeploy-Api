$OctopusURL = ## YOUR URL
$APIKey = ## YOUR API KEY
$CurrentSpaceId = $OctopusParameters["Octopus.Space.Id"]
$projectIdsToIgnore = ## PROJECTS TO IGNORE

$projectListToIgnore = $projectIdsToIgnore.Split(",")

$header = @{ "X-Octopus-ApiKey" = $APIKey }

Write-Host "Getting list of all spaces"
$spaceList = (Invoke-WebRequest "$OctopusUrl/api/Spaces?skip=0&take=100000" -Headers $header).content | ConvertFrom-Json
$badProjectsFound = $false
$badProjectList = ""

foreach ($space in $spaceList.Items)
{
    $spaceId = $space.Id
    if ($spaceId -ne $CurrentSpaceId)
    {
        Write-Host "Getting all the projects for $spaceId"
        $projectList = (Invoke-WebRequest "$OctopusUrl/api/$spaceId/projects/all" -Headers $header).content | ConvertFrom-Json
        $projectCount = $taskList.Count

        Write-Host "Found $projectCount projects in $spaceId space"
        foreach ($project in $projectList)
        {
            $projectId = $project.Id
            $projectName = $project.Name
            $projectWebUrl = $OctopusUrl + $project.Links.Web

            if ($projectListToIgnore -contains $projectId)
            {
                Write-Host "Project $projectName in $spaceId is on the ignore list, skipping"
            }
            else
            {
                Write-Host "Getting the deployment process for $projectName in $spaceId"
                $deploymentProcessUrl = $OctopusUrl + $project.Links.DeploymentProcess
                $projectProcess = (Invoke-WebRequest $deploymentProcessUrl -Headers $header).content | ConvertFrom-Json

                $manualInterventionActive = $false
                $trafficCopDeployment = $false

                foreach ($step in $projectProcess.Steps)
                {
                    foreach ($action in $step.Actions)
                    {
                        if ($action.ActionType -eq "Octopus.DeployRelease")
                        {
                            $trafficCopDeployment = $true
                        }
                        elseif ($action.ActionType -eq "Octopus.Manual" -and $action.IsDisabled -eq $false)
                        {
                            $manualInterventionActive = $true
                        }
                    }
                }

                if ($trafficCopDeployment -eq $true)
                {
                    Write-Host "Project $projectName is a traffic cop project, skipping checks"
                }
                elseif ($manualInterventionActive -eq $false)
                {
                    Write-Highlight "Project $projectName is missing a manual intervention step"
                    $badProjectsFound = $true
                    $badProjectList += "The project $projectName found at $projectWebUrl does not have a active manual intervention step
"
                }
            }

            
        }
        
    }
}

Set-OctopusVariable -name "BadProjectsFound" -value $badProjectsFound
Set-OctopusVariable -name "BadProjectList" -value $badProjectList