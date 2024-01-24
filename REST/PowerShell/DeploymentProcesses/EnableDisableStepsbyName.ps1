# This script is designed to find steps in Runbooks and deployment processes with an exact name, then enable or disable the step via $disable

$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://YOUR_OCTOPUS_URL"
$octopusAPIKey = "API-XXXXXXXXXXXXXXXXXXXXXXXXX"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"
$stepName = "STEP_NAME_HERE"
$disable = $false # Set to $true to disable applicable steps. Set to $false to enable applicable steps

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object { $_.Name -eq $spaceName }

# Get projects for space
$projectList = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header

# Loop through projects
foreach ($project in $projectList) {
    
	# If you do not want to apply this to Runbooks, comment out the section noted below
	# <-------->
    $runbooksListLink = "/api/$($space.Id)/projects/$($project.Id)/runbooks/all"
    $runbooksList = Invoke-RestMethod -Method Get -Uri "$octopusURL$runbooksListLink" -Headers $header

    # Loop through runbooks
    foreach ($runbook in $runbooksList) {
        $runbookProcessLink = $runbook.Links.RunbookProcesses

         try {
        $runbookProcess = Invoke-RestMethod -Method Get -Uri "$octopusURL$runbookProcessLink" -Headers $header | Where-Object { $_.steps.name -contains $stepName }
        }
        catch {
            Write-Host "---"
            Write-Warning "Failed to GET the Runbook process for `"$($runbook.Name)`" inside the Project `"$($project.Name)`" via the following URL: $octopusURL$runbookProcessLink"
        }
        # Find and enable/disable Steps in Runbook process
        if ($runbookProcess.Steps.name -contains $stepName) { 
            $modifiedRunbookProcess = $runbookProcess
            Foreach ($action in $modifiedRunbookProcess.Steps.actions | Where-Object { $_.Name -eq $stepName }) {
                $action.IsDisabled = $disable
            }
            $updatedRunbookProcess = Invoke-RestMethod -Method Put -Uri "$octopusURL$runbookProcessLink" -Headers $header -Body ($modifiedRunbookProcess | ConvertTo-Json -Depth 10)
            If ($disable) {
                Write-Host "Disabled step `"$stepName`" in Runbook `"$($runbook.Name)`" inside the Project `"$($project.Name)`. ($octopusURL$runbookProcessLink)"
            }
            If (!$disable) {
                Write-Host "Enabled step `"$stepName`" in Runbook `"$($runbook.Name)`" inside the Project `"$($project.Name)`. ($octopusURL$runbookProcessLink)"
            }
        Write-Host "---"
        }       
    }
	# <-------->

    $deploymentProcessLink = $project.Links.DeploymentProcess

    # Check if project is Config-as-Code
    if ($project.IsVersionControlled) {
        # Get default Git branch for Config-as-Code project
        $defaultBranch = $project.PersistenceSettings.DefaultBranch
        $deploymentProcessLink = $deploymentProcessLink -Replace "{gitRef}", $defaultBranch
    }
    $deploymentProcess = $null
    try {
        $deploymentProcess = Invoke-RestMethod -Method Get -Uri "$octopusURL$deploymentProcessLink" -Headers $header | Where-Object { $_.steps.name -contains $stepName }
    }
    catch {
        Write-Warning "Failed to GET the deployment process for `"$($project.Name)`" via the following URL: $octopusURL$deploymentProcessLink"
        Write-Host "---"
    }

    # Find and enable/disable Steps in deployment process
    if ($deploymentProcess.Steps.name -contains $stepName) { 
        $modifiedProcess = $deploymentProcess
        Foreach ($action in $modifiedProcess.Steps.actions | Where-Object { $_.Name -eq $stepName }) {
            $action.IsDisabled = $disable
        }
        $updatedDeploymentProcess = Invoke-RestMethod -Method Put -Uri "$octopusURL$deploymentProcessLink" -Headers $header -Body ($modifiedProcess | ConvertTo-Json -Depth 10)
        If ($disable) {
            Write-Host "Disabled step `"$stepName`" deployment process for the Project `"$($project.Name)`. ($octopusURL$deploymentProcessLink)"
        }
        If (!$disable) {
            Write-Host "Enabled step `"$stepName`" deployment process for the Project `"$($project.Name)`. ($octopusURL$deploymentProcessLink)"
        }
        Write-Host "---"
    }
}