$OctopusURL = YOUR OCTOPUS SERVER
$APIKey = API KEY WITH PERMISSIONS TO CANCEL DEPLOYMENTS, RETRY DEPLOYMENTS AND DELETE WORKERS
$workerName = "*YOUR WORKER MACHINE NAME*"

$header = @{ "X-Octopus-ApiKey" = $APIKey }

Write-Host "Getting list of all spaces"
$spaceList = (Invoke-WebRequest "$OctopusUrl/api/Spaces?skip=0&take=100000" -Headers $header).content | ConvertFrom-Json
$cancelledDeploymentList = @()

#Cancel any deployments for the worker
foreach ($space in $spaceList.Items)
{
    $spaceId = $space.Id
    Write-Host "Checking $spaceId for running tasks (looking for executing tasks only)"
    $taskList = (Invoke-WebRequest "$OctopusUrl/api/tasks?skip=0&states=Executing&spaces=$spaceId&take=100000" -Headers $header).content | ConvertFrom-Json
    $taskCount = $taskList.TotalResults

    Write-Host "Found $taskCount currently running tasks"
    foreach ($task in $taskList.Items)
    {
        $taskId = $task.Id            

        if ($task.Name -eq "Deploy"){
            # The running task is a deployment, get the details including all the logs                
            $taskDetails = (Invoke-WebRequest "$OctopusUrl/api/tasks/$taskId/details?verbose=true&tail=1000" -Headers $header).content | ConvertFrom-Json
            $activityLogs = $taskDetails.ActivityLogs

            foreach($activity in $activityLogs)
            {
                $childrenList = $activity.Children
                
                foreach ($child in $childrenList)
                {
                    Write-Host $child                        
                    if ($child.Status -eq "Running")
                    {
                        $grandchildList = $child.Children
                        foreach($grandchild in $grandchildList)
                        {
                            if ($grandchild.Name -eq "Worker")
                            {
                                $logElements = $grandchild.LogElements
                                foreach($log in $logElements)
                                {     
                                    Write-Host $log.MessageText                                   
                                    if ($log.MessageText -like $workerName)
                                    {
                                        Write-Host "$taskId is currently running on the worker we want to delete, going to cancel it"
                                        $cancelledDeploymentList += @{
                                            SpaceId = $taskDetails.Task.SpaceId
                                            DeploymentId = $taskDetails.Task.Arguments.DeploymentId
                                        }
                                        Invoke-WebRequest "$OctopusUrl/api/tasks/$taskId/cancel" -Headers $header -Method Post
                                        break;
                                    }
                                }                                    
                            }
                        }                                                        
                    }
                }
            }
        }                        
    }
}

$cancelledDeploymentsCount = $cancelledDeployments.Count
Write-Host "This process caused me to cancel $cancelledDeploymentsCount deployments, going to delete the worker and retry them"

## Delete Worker Logic GOES HERE

## Retry logic for the cancelled deployments
foreach ($cancelledDeployment in $cancelledDeploymentList)
{
    Write-Host $cancelledDeployment.DeploymentId

    $deploymentSpaceId = $cancelledDeployment.SpaceId    
    $deploymentId = $cancelledDeployment.DeploymentId

    $deploymentInfo = (Invoke-WebRequest "$OctopusUrl/api/$deploymentSpaceId/Deployments/$deploymentId" -Headers $header -Method GET) | ConvertFrom-Json

    $bodyRaw = @{
        EnvironmentId = $deploymentInfo.EnvironmentId
        ExcludedMachineIds = $deploymentInfo.ExcludedMachineIds
        ForcePackageDownload = $deploymentInfo.ForcePackageDownload
        ForcePackageRedeployment = $deploymentInfo.ForcePackageRedeployment
        FormValues = $deploymentInfo.FormValues
        QueueTime = $null
        QueueTimeExpiry = $null
        ReleaseId = $deploymentInfo.ReleaseId
        SkipActions = $deploymentInfo.SkipActions
        SpecificMachineIds = $deploymentInfo.SpecificMachineIds
        TenantId = $deploymentInfo.TenantId
        UseGuidedFailure = $deploymentInfo.UseGuidedFailure
    } 

    $bodyAsJson = $bodyRaw | ConvertTo-Json

    $redeployment = (Invoke-WebRequest "$OctopusURL/api/$deploymentSpaceId/deployments" -Headers $header -Method Post -Body $bodyAsJson -ContentType "application/json").content | ConvertFrom-Json
    $taskId = $redeployment.TaskId
    Write-Host "Starting the deployment again after cancelling, it has a task id of $taskId"
}