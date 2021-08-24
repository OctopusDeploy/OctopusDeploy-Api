$OctopusServerUrl = ""  #PUT YOUR SERVER LOCATION HERE. (e.g. http://localhost)
$ApiKey = ""   #PUT YOUR API KEY HERE
$taskname = "SynchronizeExternalSecurityGroupsForUsers" #IF YOU WANT TO RUN A DIFFERENT TASK, MODIFY THIS VARIABLE

$task = Invoke-RestMethod -Method "get" "$OctopusServerUrl/api/tasks?take=1&skip=0&name=$($taskname)&spaces=all&includeSystem=true" -Headers @{"X-Octopus-ApiKey" = $ApiKey }
$rerunurl = $task.Items[0].Links.Rerun
Invoke-RestMethod -Method "POST" "$OctopusServerUrl$($rerunurl)" -Headers @{"X-Octopus-ApiKey" = $ApiKey }
