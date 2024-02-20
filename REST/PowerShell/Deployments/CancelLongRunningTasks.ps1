$OctopusURL = $OctopusParameters["Global.Base.Url"]
$APIKey = $OctopusParameters["Global.Api.Key"]
$CurrentSpaceId = $OctopusParameters["Octopus.Space.Id"]
$MaxRunTime = 15

$header = @{ "X-Octopus-ApiKey" = $APIKey }

Write-Host "Getting list of all spaces"
$spaceList = (Invoke-RestMethod "$OctopusUrl/api/Spaces?skip=0&take=100000" -Headers $header)
$cancelledTask = $false
$cancelledTaskList = ""

foreach ($space in $spaceList.Items)
{
    $spaceId = $space.Id
    if ($spaceId -ne $CurrentSpaceId)
    {
        Write-Host "Checking $spaceId for running tasks (looking for executing tasks only)"
        $taskList = (Invoke-RestMethod" $OctopusUrl/api/tasks?skip=0&states=Executing&spaces=$spaceId&take=100000" -Headers $header)
        $taskCount = $taskList.TotalResults

        Write-Host "Found $taskCount currently running tasks"
        foreach ($task in $taskList.Items)
        {
            $taskId = $task.Id
            $taskDescription = $task.Description

            if ($task.Name -eq "Deploy"){
                # With auto deployment triggers enabled, the start time of the task cannot be trusted, need to find the events for the most recent deployment started
                $eventList = (Invoke-RestMethod "$OctopusUrl/api/events?regardingAny=$taskId&spaces=$spaceId&includeSystem=true" -Headers $header)
                foreach ($event in $eventList.Items){
                    if ($event.Category -eq "DeploymentStarted"){
                        $startTime = (Get-Date $event.Occurred)
                        
                        # We found the most recent deployment event started we are curious about, stop looping through
                        break;
                    }            
                }
            }
            else{
                $startTime = (Get-Date $task.StartTime)
            }

            $currentTime = Get-Date                        
            $dateDiff = $currentTime - $startTime

            Write-Host "The task $taskDescription has been running for $dateDiff"

            if ($dateDiff.TotalMinutes -gt $MaxRunTime){
                Write-Highlight "The task $taskDescription has been running for over $MaxRunTime minutes, this indicates a problem, let's cancel it"

                Invoke-RestMethod "$OctopusUrl/api/tasks/$taskId/cancel" -Headers $header -Method Post

                $cancelledTask = $true
                $cancelledTaskList += $taskDescription + "
                "
            }            
        }
    }
}

Set-OctopusVariable -name "CancelledTask" -value $cancelledTask
Set-OctopusVariable -name "CancelledTaskList" -value $cancelledTaskList
