# This script is designed to find the usage for a specific Worker Pool, then print the Step, Project, and/or Runbook associated with it

$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://YOUR_OCTOPUS_URL"
$octopusAPIKey = "API-XXXXXXXXXXXXXXXXXXXXXXXXX"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"
$workerPoolName = "WORKER_POOL_NAME_HERE"

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object { $_.Name -eq $spaceName }

# Get worker pool id
$workerPool = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/workerpools/all" -Headers $header) | Where-Object { $_.Name -eq $workerPoolName }

# Get projects for space
$projectList = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header

# Loop through projects
foreach ($project in $projectList) {
    
    $runbooksListLink = "/api/$($space.Id)/projects/$($project.Id)/runbooks/all"
    $runbooksList = Invoke-RestMethod -Method Get -Uri "$octopusURL$runbooksListLink" -Headers $header

    # Loop through runbooks
    foreach ($runbook in $runbooksList) {
        $runbookProcessLink = $runbook.Links.RunbookProcesses

         try {
        $runbookProcess = Invoke-RestMethod -Method Get -Uri "$octopusURL$runbookProcessLink" -Headers $header
        }
        catch {
            Write-Host "---"
            Write-Warning "Failed to GET the Runbook process for `"$($runbook.Name)`" inside the Project `"$($project.Name)`" via the following URL: $octopusURL$runbookProcessLink"
        }
        # Get runbook steps and check step for specified worker pool
        foreach ($step in $runbookProcess.Steps) {
            $stepWorkerPool = $step.Actions.WorkerPoolId
            if ($null -ne $stepWorkerPool) {
                if ($stepWorkerPool -eq $($workerPool.Id)) {
                    Write-Host "---"
                    Write-Host "Step `"$($step.Name)`" of Runbook `"$($runbook.Name)`" inside the Project `"$($project.Name)`" is using `"$($workerPool.name)`" ($($workerPool.Id)`)."
                }
            }
        }
    }

    $deploymentProcessLink = $project.Links.DeploymentProcess

    # Check if project is Config-as-Code
    if ($project.IsVersionControlled) {
        # Get default Git branch for Config-as-Code project
        $defaultBranch = $project.PersistenceSettings.DefaultBranch
        $deploymentProcessLink = $deploymentProcessLink -Replace "{gitRef}", $defaultBranch
    }

    try {
        $deploymentProcess = Invoke-RestMethod -Method Get -Uri "$octopusURL$deploymentProcessLink" -Headers $header
    }
    catch {
        Write-Host "---"
        Write-Warning "Failed to GET the deployment process for `"$($project.Name)`" via the following URL: $octopusURL$deploymentProcessLink"
    }

    # Get project steps and check step for specified worker pool
    foreach ($step in $deploymentProcess.Steps) {
        $stepWorkerPool = $step.Actions.WorkerPoolId
        if ($null -ne $stepWorkerPool) {
            if ($stepWorkerPool -eq $($workerPool.Id)) {
                Write-Host "---"
                Write-Host "Step `"$($step.Name)`" of Project `"$($project.Name)`" is using `"$($workerPool.name)`" ($($workerPool.Id)`)."
            }
        }
    }
}
