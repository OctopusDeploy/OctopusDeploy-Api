$ErrorActionPreference = "Stop";

<#
Get a list of the worker machines that have been used in tasks.

Outputs a carat separated file with the following headings: 
"TaskId","TaskName","TaskDescription","Started","Ended","MessageText","WorkerName","WorkerPool"

NB - assumes worker machine name has no spaces.

#>

# Define working variables
$octopusURL = "https://my.octopus.url"
$octopusAPIKey = ""
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$spaceName = "Default"
$skip = 0
$take = 30
$maxTasksToCheck = 100

Set-Content "./OutputWorkers.csv" -Value $null

# Get space
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -eq $spaceName }
$spaceId = $space.Id

$continueTasks = $true;
$taskProperties = [System.Collections.ArrayList]::new();
$taskProperties.Add(@("TaskId","TaskName","TaskDescription","Started","Ended","MessageText","WorkerName","WorkerPool"))

function Get-WorkerInfo($activityLogElement){
    foreach ($logChild1 in $activityLogElement.Children) {
        foreach ($logElement in $logChild1.LogElements) {
            if ($logElement.MessageText -clike 'Leased worker*') {

                # Get worker detail from the message
                $splitMessage = $logElement.MessageText.Split(' ')
                $workerName = $splitMessage[2]
                $workerPoolItemSection = $splitMessage.Length - 5
                $workerPoolAndLease = ($splitMessage | Select-Object -Last $workerPoolItemSection) -join " "
                $workerPoolName = $workerPoolAndLease.Split('(')[0]

                $taskProperties.Add(@(
                        $task.Id,
                        $task.Name,
                        $task.Description,
                        $task.StartTime,
                        $task.CompletedTime,
                        $logElement.MessageText,
                        $workerName,
                        $workerPoolName)
                )
            }
        }
    }
}


while ($continueTasks -eq $true -and $skip -lt $maxTasksToCheck){
            
    Write-Host "skip: $($skip)"
    # Get tasks
    $tasks = Invoke-RestMethod -Uri "$octopusURL/api/tasks?skip=$($skip)&take=$($take)&spaces=$($spaceId)&includeSystem=false&name=deploy,runbookrun" -Headers $header 
    $taskItems = $tasks.Items 

    if ($taskItems.Count -eq 0){
        $continueTasks = $false;
    } else {

        foreach ($task in $taskItems) {
            #Write-Host $task.Id $task.Description
            
            # Get task detail
            $taskDetail = Invoke-RestMethod -Uri "$octopusURL/api/tasks/$($task.Id)/details?verbose=true" -Headers $header 

            foreach ($activityLog in $taskDetail.ActivityLogs) {
                foreach ($activityLogChild1 in $activityLog.Children) {
                    Get-WorkerInfo $activityLogChild1

                    foreach ($activityLogChild2 in $activityLogChild1.Children) {
                        Get-WorkerInfo $activityLogChild2            
                    }
                        
                }
            }
        }
    }
    
    foreach ($arr in $taskProperties) {
        $arr -join '^' | Add-Content "./OutputWorkers.csv"
    }

    $taskProperties = [System.Collections.ArrayList]::new();
    $skip += $take

} 



