###
# NOTE: This script makes use of an API endpoint introduced in Octopus 2021.1 for the Export/Import Projects feature
# Using this script in earlier versions of Octopus will not work.
# # See https://octopus.com/docs/projects/export-import for details.
###
$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app/"
$octopusAPIKey = "API-KEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

# Provide the space name for the projects to export.
$spaceName = "Default"
# Provide a list of project names to export.
$projectNames = @("Project A", "Project B")
# Provide a password for the export zip file
$exportTaskPassword = ""
# Wait for the export task to finish?
$exportTaskWaitForFinish = $True
# Provide a timeout for the export task to be canceled.
$exportTaskCancelInSeconds=300

$octopusURL = $octopusURL.TrimEnd('/')

# Get Space
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -eq $spaceName }
$exportTaskSpaceId = $space.Id

$exportTaskProjectIds = @()

if (![string]::IsNullOrWhiteSpace($projectNames)) {
    @(($projectNames -Split "`n").Trim()) | ForEach-Object {
        if (![string]::IsNullOrWhiteSpace($_)) {
            Write-Verbose "Working on: '$_'"
            $projectName = $_.Trim()
            if([string]::IsNullOrWhiteSpace($projectName)) {
                throw "Project name is empty'"
            }
            $projects = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/projects?partialName=$([uri]::EscapeDataString($projectName))&skip=0&take=100" -Headers $header 
			$project = $projects.Items | Where-Object { $_.Name -eq $projectName }
            $exportTaskProjectIds += $project.Id
        }
    }
}

$exportBody = @{
    IncludedProjectIds = $exportTaskProjectIds;
    Password = @{
    	HasValue = $True;
        NewValue = $exportTaskPassword;
    }
}

$exportBodyAsJson = $exportBody | ConvertTo-Json
$exportBodyPostUrl = "$octopusURL/api/$($exportTaskSpaceId)/projects/import-export/export"
Write-Host "Kicking off export run by posting to $exportBodyPostUrl"
Write-Verbose "Payload: $exportBodyAsJson"
$exportResponse = Invoke-RestMethod $exportBodyPostUrl -Method POST -Headers $header -Body $exportBodyAsJson
$exportServerTaskId = $exportResponse.TaskId
Write-Host "The task id of the new task is $exportServerTaskId"
Write-Host "Export task was successfully invoked, you can access the task: $octopusURL/app#/$exportTaskSpaceId/tasks/$exportServerTaskId"

if ($exportTaskWaitForFinish -eq $true)
{
	Write-Host "The setting to wait for completion was set, waiting until task has finished"
    $startTime = Get-Date
    $currentTime = Get-Date
    $dateDifference = $currentTime - $startTime
    $taskStatusUrl = "$octopusURL/api/$exportTaskSpaceId/tasks/$exportServerTaskId"
    $numberOfWaits = 0    
    While ($dateDifference.TotalSeconds -lt $exportTaskCancelInSeconds)
    {
        Write-Host "Waiting 5 seconds to check status"
        Start-Sleep -Seconds 5
        $taskStatusResponse = Invoke-RestMethod $taskStatusUrl -Headers $header        
        $taskStatusResponseState = $taskStatusResponse.State
        if ($taskStatusResponseState -eq "Success")
        {
            Write-Host "The task has finished with a status of Success"
            $artifactsUrl= "$octopusURL/api/$exportTaskSpaceId/artifacts?regarding=$exportServerTaskId"
            Write-Host "Checking for artifacts from $artifactsUrl"
            $artifacts = Invoke-RestMethod $artifactsUrl -Method GET -Headers $header
            $exportArtifact = $artifacts.Items | Where-Object { $_.Filename -like "Octopus-Export-*.zip"} 
            Write-Host "Export task successfully completed, you can download the export archive: $octopusURL$($exportArtifact.Links.Content)"
            exit 0
        }
        elseif($taskStatusResponseState -eq "Failed" -or $taskStatusResponseState -eq "Canceled")
        {
            Write-Host "The task has finished with a status of $taskStatusResponseState status, completing"
            exit 1            
        }
        $numberOfWaits += 1
        if ($numberOfWaits -ge 10)
        {
        	Write-Host "The task state is currently $taskStatusResponseState"
        	$numberOfWaits = 0
        }
        else
        {
        	Write-Host "The task state is currently $taskStatusResponseState"
        }  
        $startTime = $taskStatusResponse.StartTime
        if ($null -eq $startTime -or [string]::IsNullOrWhiteSpace($startTime) -eq $true)
        {        
        	Write-Host "The task is still queued, let's wait a bit longer"
        	$startTime = Get-Date
        }
        $startTime = [DateTime]$startTime
        $currentTime = Get-Date
        $dateDifference = $currentTime - $startTime        
    }
    Write-Host "The cancel timeout has been reached, cancelling the export task"
    Invoke-RestMethod "$octopusURL/api/$exportTaskSpaceId/tasks/$exportTaskSpaceId/cancel" -Headers $header -Method Post | Out-Null
    Write-Host "Exiting with an error code of 1 because we reached the timeout"
    exit 1
}