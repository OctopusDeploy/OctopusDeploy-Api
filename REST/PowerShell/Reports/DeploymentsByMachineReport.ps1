$ErrorActionPreference = "Stop";

# Fix ANSI Color on PWSH Core issues when displaying objects
if ($PSEdition -eq "Core") {
    $PSStyle.OutputRendering = "PlainText"
}

$stopwatch = [system.diagnostics.stopwatch]::StartNew()

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-KEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"

$deploymentsFrom = "2024-06-19"
$deploymentsTo = "2024-06-20"

# Project filters
$projectNames = @("Project 1", "Project 2")

# Environment filters
$environmentNames = @("Development", "Test")

$csvExportPath = "" # /path/to/export.csv

# Get space
Write-Output "Retrieving space '$($spaceName)'"
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -ieq $spaceName }

# cache certain resources as they are retrieved if enabled
$cacheItems = $true

$releases = @()
$deployments = @()
$serverTasks = @()
$serverTaskDetails = @()

# Cache all environments
Write-Output "Retrieving all environments"
$environments = @()
$response = $null
do {
    $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/$($space.Id)/environments" }
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
    $environments += $response.Items
} while ($response.Links.'Page.Next')

# Cache all tenants
Write-Output "Retrieving all tenants"
$tenants = @()
$response = $null
do {
    $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/$($space.Id)/tenants" }
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
    $tenants += $response.Items
} while ($response.Links.'Page.Next')

# Cache all machines
Write-Output "Retrieving all machines"
$machines = @()
$response = $null
do {
    $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/$($space.Id)/machines" }
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
    $machines += $response.Items
} while ($response.Links.'Page.Next')

# Cache all projects
Write-Output "Retrieving all projects"
$projects = @()
$response = $null
do {
    $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/$($space.Id)/projects" }
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
    $projects += $response.Items
} while ($response.Links.'Page.Next')

# Return the cached release or retrieve it, cache it and then return it.
function Get-Release {
    param($releaseId)
    
    $release = @($releases | Where-Object { $_.Id -ieq $releaseId }) | Select-Object -First 1
    if ($null -ieq $release) {
        $release = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/releases/$($releaseId)" -Headers $header 
        if ($cacheItems) {
            $releases += $release
        }
    }
    
    return $release
}

function Get-Deployment {
    param($deploymentId)
    
    $deployment = @($deployments | Where-Object { $_.Id -ieq $deploymentId }) | Select-Object -First 1
    if ($null -ieq $deployment) {
        $deployment = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/deployments/$($deploymentId)" -Headers $header 
        if ($cacheItems) {
            $deployments += $deployment
        }
    }
    
    return $deployment
}

function Get-ServerTask {
    param($taskId)
    
    $serverTask = @($serverTasks | Where-Object { $_.Id -ieq $taskId }) | Select-Object -First 1
    if ($null -ieq $serverTask) {
        $serverTask = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/tasks/$($taskId)" -Headers $header 
        if ($cacheItems) {
            $serverTasks += $serverTask
        }
    }
    
    return $serverTask
}

function Get-ServerTaskDetails {
    param($taskId)
    
    $serverTaskDetail = @($serverTaskDetails | Where-Object { $_.Id -ieq $taskId }) | Select-Object -First 1
    if ($null -ieq $serverTask) {
        $serverTaskDetail = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/tasks/$($taskId)/details?verbose=false&tail=50&ranges=" -Headers $header 
        if ($cacheItems) {
            $serverTaskDetails += $serverTaskDetail
        }
    }
    
    return $serverTaskDetail
}

$eventsUrl = "$octopusURL/api/events?includeSystem=false&spaces=$($space.Id)&eventCategories=DeploymentStarted&documentTypes=Deployments&from=$($deploymentsFrom)T00%3A00%3A00%2B00%3A00&to=$($deploymentsTo)T23%3A59%3A59%2B00%3A00"

# Check for optional projects filter
if ($projectNames.Length -gt 0) {
    Write-Verbose "Filtering events to projects '$($projectNames -Join ",")'"
    $filteredProjects = @($projects | Where-Object { $projectNames -icontains $_.Name } | ForEach-Object { "$($_.Id)" }) 
    $projectsOperator = $filteredProjects -Join ","
    $eventsUrl += "&projects=$projectsOperator"
}
# Check for optional environments filter
if ($environmentNames.Length -gt 0) {
    Write-Verbose "Filtering events to environments '$($environmentNames -Join ",")'"
    $filteredEnvironments = @($environments | Where-Object { $environmentNames -icontains $_.Name } | ForEach-Object { "$($_.Id)" }) 
    $environmentsOperator = $filteredEnvironments -Join ","
    $eventsUrl += "&environments=$environmentsOperator"
}

# Get events
Write-Output "Retrieving deployment events from '$($deploymentsFrom)' to '$($deploymentsTo)'"
$events = @()
$response = $null
do {
    $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { $eventsUrl }
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
    $events += $response.Items
} while ($response.Links.'Page.Next')

$results = @()

foreach ($event in $events) {
    Write-Verbose "Working on event $($event.Id)"
    # Get related document Ids
    $releaseId = $event.RelatedDocumentIds | Where-Object { $_ -like "Releases-*" } | Select-Object -First 1
    $projectId = $event.RelatedDocumentIds | Where-Object { $_ -like "Projects*" } | Select-Object -First 1
    $deploymentId = $event.RelatedDocumentIds | Where-Object { $_ -like "Deployments*" } | Select-Object -First 1
    $environmentId = $event.RelatedDocumentIds | Where-Object { $_ -like "Environments*" } | Select-Object -First 1
    $taskId = $event.RelatedDocumentIds | Where-Object { $_ -like "ServerTasks*" } | Select-Object -First 1
    
    # Get objects
    $project = $projects | Where-Object { $_.Id -ieq $projectId }
    $environment = $environments | Where-Object { $_.Id -ieq $environmentId } 
    $release = Get-Release -ReleaseId $releaseId 
    $deployment = Get-Deployment -DeploymentId $deploymentId
    $task = Get-ServerTask -TaskId $TaskId 
    $taskDetails = Get-ServerTaskDetails -TaskId $taskId
    $activityLogs = $taskDetails.ActivityLogs | Select-Object -First 1
      
    $tenantName = ""

    if (-not [string]::IsNullOrWhitespace($deployment.TenantId)) {
        $tenantName = ($tenants | Where-Object { $_.Id -ieq $deployment.TenantId }).Name
    }

    $deployedToMachines = $deployment.DeployedToMachineIds

    foreach ($machineId in $deployedToMachines) {
        $machineName = ($machines | Where-Object { $_.Id -ieq $machineId }).Name
        $machineStatus = [string]::Empty
        $stepDetails = [string]::Empty

        # Each stepLog could have a .Status property of "Skipped", "Pending", "Success" or "Failed".
        $stepLogs = $activityLogs.Children 
        foreach ($stepLog in $stepLogs) {
            # There should be at least one child-entry per machine, including when doing a rolling deployment
            $firstMatchingFailedLogEntryForMachine = $stepLog.Children | Where-Object { $_.Name -ieq $machineName -and $_.Status -ieq "Failed" } | Select-Object -First 1
            if ($null -ne $firstMatchingFailedLogEntryForMachine) {
                Write-Verbose "Found a failed step for machine '$machineName' - $($stepLog.Name)"
                $machineStatus = "Fail"
                $stepDetails = "Failed—$($stepLog.Name)"
                break;
            }
            $firstMatchingPendingLogEntryForMachine = $stepLog.Children | Where-Object { $_.Name -ieq $machineName -and $_.Status -ieq "Pending" }
            if ($null -ne $firstMatchingPendingLogEntryForMachine) {
                Write-Verbose "Found a pending step for machine '$machineName' - $($stepLog.Name)"
                $machineStatus = "Fail"
                $stepDetails = "Pending—$($stepLog.Name)"
                break;
            }

            # If you don't want a skipped step to indicate a failure, remove this block of code.
            $firstMatchingSkippedLogEntryForMachine = $stepLog.Children | Where-Object { $_.Name -ieq $machineName -and $_.Status -ieq "Skipped" } | Select-Object -First 1
            if ($null -ne $firstMatchingSkippedLogEntryForMachine) {
                Write-Verbose "Found a skipped step for machine '$machineName' - $($stepLog.Name)"
                $machineStatus = "Fail"
                $stepDetails = "Skipped—$($stepLog.Name)"
                break;
            }   
        }

        if ([string]::IsNullOrWhiteSpace($machineStatus)) {
            $machineStatus = "Pass"
        }

        $result = [PsCustomObject]@{
            Project          = $project.Name
            Release          = $release.Version
            Environment      = $environment.Name
            Tenant           = $tenantName
            DeploymentTarget = $machineName
            MachineStatus    = $machineStatus
            StepDetails      = $stepDetails
            StartTime        = $task.StartTime
            CompletedTime    = $task.CompletedTime
        }
        $results += $result
    }
}

if ($results.Count -gt 0) {
    Write-Output ""
    Write-Output "Found $($results.Count) results:"
    if (![string]::IsNullOrWhiteSpace($csvExportPath)) {
        Write-Output "Exporting results to CSV file: $csvExportPath"
        $results | Export-Csv -Path $csvExportPath -NoTypeInformation
    }
    else {
        $results | Sort-Object -Property Project, Release, Environment, QueueTime | Format-Table -Property * | Out-String -Width 1000
    }
}

$stopwatch.Stop()
Write-Output "Completed report execution in $($stopwatch.Elapsed)"