<#
    This will return all machines that did not complete the deployment task, meaning they were not in the role/environment at the time of execution
    or were skipped as a decision during guided failure mode.
    
    Note: In guided failure mode, if ignore is chosen the task will complete on the target and the record will exist. Excluding the target will 
    return expected result.

    End result is a generic list object $missedTargets which contains machine id's. This can be output to a file or used as input for another process.
#>

$octopusAPIkey = ""             #Octopus API Key
$octopusURL = ""                #Octopus URL
$role = ""                      #Role that includes targets to investigate
$project = ""                   #Project name to search for
$releaseVersion = ""            #Release version of project
$targetEnvironment = ""         #Target environment
$returnMachineTasks = 100       #Number of machine tasks to return

# Add key to header object for api call
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }


# Get environment list, grab environment id for named environment
$allEnvironments = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/environments" -Headers $header)
$environmentItem = $allEnvironments.Items | where-object { $_.Name -eq $targetEnvironment }
$environmentId = $environmentItem.Id

# Get project details
$projectDetails = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/projects/$project" -Headers $header)

# Get project releases
$releases = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/projects/$($projectDetails.Id)/releases?skip=0&take=100" -Headers $header)

# List versions for given releases, get release ID for specified version
$items = $releases.Items
$release = $items | Where-Object { $_.Version -EQ $releaseVersion }

# Get list of machines from each step with the specified role for the release
$deploymentDetails = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($Release.SpaceId)/releases/$($Release.Id)/deployments/preview/$($environmentId)?includeDisabledSteps=true" -Headers $header)
$deploymentStepsInRole = $deploymentDetails.StepsToExecute  | Where-Object { $_.Roles -Contains $role }

# Populate hash with list of initial target machines
$targetMachines = @{}
Foreach ($step in $deploymentStepsInRole) {
    $machineList = $Step.machines
    foreach ($mach in $machineList) {
        if ($targetMachines.contains($mach.Id)) {
            continue
        }
        else {
            $targetMachines.Add($mach.Id, $mach.Name)
        }
    }
}

Write-Output "Initial targets: $($targetMachines.Count)"

# Get task ID's for each deployment to check completion status
$releaseDeployments = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/releases/$($Release.Id)/deployments?skip=0&take=100" -Headers $header)
$releaseDeployment = $releaseDeployments.Items | where-object { $_.EnvironmentId -eq $environmentId }

# Create server task list object of successful deployments. Use as base for machine task comparison

$serverTaskIds = New-Object System.Collections.Generic.List[System.Object]

# Query task endpoint for success - for each success get task Id and add to server task list
ForEach ($deployment in $releaseDeployment) {
        
    $taskId = $deployment.TaskId
    $serverTaskDetail = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/tasks/$taskId" -Headers $header) 
    #$serverTaskDetail 
    If ($serverTaskDetail.State -eq "Success") {
        $serverTaskIds.add($serverTaskDetail.Id)
    }
}

$startTime = Get-Date
$machineTaskIds = New-Object System.Collections.Generic.List[System.Object]
$missedTargets = @{}
$receivedTargets = @{}
$returnMachineTasks = 100  
# Machine specific tasks
Foreach ($machine in $targetMachines.GetEnumerator()) {
    Write-Output "Processing tasks for $($machine.Value)"
    #$machineTaskIds = New-Object System.Collections.Generic.List[System.Object]
    $machineTasks = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/machines/$($machine.name)/tasks?skip=0&take=$returnMachineTasks" -Headers $header).Items
    Foreach ($task in $machinetasks) {
        $machineTaskIds.Add($task.Id)
    }
    

    # Use server task Id list (smaller) to poll machine task ids
    Foreach ($serverTask in $serverTaskIds) {
        $taskComparison = Compare-Object $machineTaskIds $serverTask -IncludeEqual | Where-Object { $_.SideIndicator -eq '=>' }
        If ($null -ne $taskComparison) {
            $missedTargets.set_item($machine.Name, $machine.Value)
        }
        else {
            $receivedTargets.set_item($machine.Name, $machine.Value)            
        }
    }
    $machineTaskIds.Clear()
        
}
$endTime = Get-Date  
$processTime = New-TimeSpan -Start $startTime -End $endTime

Write-Output "Processing Time: $processTime"

# Output contents of result objects
Write-output "Missed Targets: " $missedTargets.count $missedTargets
Write-output "------------------------------------"
Write-output "Received Targets: " $receivedTargets.count $receivedTargets