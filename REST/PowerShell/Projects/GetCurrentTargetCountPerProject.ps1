# Gives a count of enabled targets per project at the time of the script running
#
# Output in JSON in the format:
# [{
#     "Id": "Projects-61",
#     "Name": "Canary Environment",
#     "WebUrl": "https://samples.octopus.app/app#/Spaces-43/projects/Projects-61",
#     "space": "Spaces-43",
#     "TargetRoles": [
#       "@{Name=OctoFX-Web; CountOfTargets=9}"
#     ],
#     "CountOfTargets": 9
#   },
#   {
#     "Id": "Projects-63",
#     "Name": "One Environment",
#     "WebUrl": "https://samples.octopus.app/app#/Spaces-43/projects/Projects-63",
#     "space": "Spaces-43",
#     "TargetRoles": [
#       "@{Name=OctoFX-Web-Canary; CountOfTargets=2}",
#       "@{Name=OctoFX-Web; CountOfTargets=9}"
#     ],
#     "CountOfTargets": 11
#   },
#   {
#     "Id": "Projects-41",
#     "Name": "Project1",
#     "WebUrl": "https://samples.octopus.app/app#/Spaces-42/projects/Projects-41",
#     "space": "Spaces-42",
#     "TargetRoles": [],
#     "CountOfTargets": 0
#   }
# ]
#
#-------------------------------------------------------------------------

$OctopusURL = ## YOUR URL
$APIKey = ## YOUR API KEY
$projectIdsToIgnore = "" ## PROJECTS TO IGNORE

$projectListToIgnore = $projectIdsToIgnore.Split(",")

# ---- Utility Functions --------------------------
# Create custom object
function Get-TargetObject($targetRoleName){
    return [pscustomobject] @{   
        'Name' = $targetRoleName
        'CountOfTargets' = 0
    }
}

function Get-ProjectObject($projectId, $projectName, $projectWebUrl, $space)
{      
    return [pscustomobject] @{    
        'Id' = $projectId 
        'Name' = $projectName
        'WebUrl' = $projectWebUrl
        'space' = $space
        'TargetRoles' = @()
        'CountOfTargets' = 0
    }
}

#-------------------------------------------------------------------------
function Get-ProjectTargetCount(){
    $header = @{ "X-Octopus-ApiKey" = $APIKey }

    Write-Host "Getting list of all spaces"
    $spaceList = (Invoke-WebRequest "$OctopusUrl/api/Spaces?skip=0&take=10" -Headers $header).content | ConvertFrom-Json
    $projects = @();

    foreach ($space in $spaceList.Items)
    {
        $spaceId = $space.Id
        Write-Host "Getting all the projects for $spaceId"
        $projectList = (Invoke-WebRequest "$OctopusUrl/api/$spaceId/projects/all" -Headers $header).content | ConvertFrom-Json
        $projectCount = $taskList.Count


        Write-Host "Found $projectCount projects in $spaceId space"
        foreach ($project in $projectList)
        {
            $projectWebUrl = $OctopusUrl + $project.Links.Web
            $projectObj = Get-ProjectObject $project.Id $project.Name $projectWebUrl $spaceId
            $targets = @();


            if ($projectListToIgnore -contains $projectObj.Id)
            {
                Write-Host "Project $($projectObj.Name) in $spaceId is on the ignore list, skipping"
            }
            else
            {
                Write-Host "Getting the deployment process for $($projectObj.Name) in $spaceId"
                $deploymentProcessUrl = $OctopusUrl + $project.Links.DeploymentProcess
                $projectProcess = (Invoke-WebRequest $deploymentProcessUrl -Headers $header).content | ConvertFrom-Json

                foreach ($step in $projectProcess.Steps)
                {
                    if($step.properties.'Octopus.Action.TargetRoles'){ 
                        $roles = $step.properties.'Octopus.Action.TargetRoles'
                        
                        if ($targets.Name -notcontains $roles)
                        {
                            $tRole = Get-TargetObject $roles
                            $targets += $tRole
                        }
                    }
                }
                $projectObj.TargetRoles = $targets

                $targetCountForProject = 0
                foreach ($targetRole in $targets){
                    Write-Host $targetRole
                    $targetUrl = "$OctopusUrl/api/$spaceId/machines?skip=0&take=2147483647&roles=$($targetRole.Name)&isDisabled=false"
                    $targetList = (Invoke-WebRequest $targetUrl -Headers $header).content | ConvertFrom-Json
                    $targetRole.CountOfTargets = $targetList.TotalResults
                    $targetCountForProject += $targetList.TotalResults
                }
                $projectObj.CountOfTargets = $targetCountForProject
            }
            $projects += $projectObj
            
        }

    }

    $projects | ConvertTo-Json
}

Get-ProjectTargetCount