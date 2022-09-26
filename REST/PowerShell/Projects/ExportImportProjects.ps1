###
# NOTE: This script makes use of API endpoints introduced in Octopus 2021.1 for the Export/Import Projects feature
# Using this script in earlier versions of Octopus will not work.
# # See https://octopus.com/docs/projects/export-import for details.
###
$ErrorActionPreference = "Stop";

# Define Source working variables
$sourceOctopusURL = "https://<source_octopus_url>/"
$sourceOctopusAPIKey = "API-KEY"

$sourceHeader = @{ "X-Octopus-ApiKey" = $sourceOctopusAPIKey }


$destinationPath = "<destination_folder>"
$destinationFile = "<file_name.zip>"
$destinationFilePath = Join-Path $destinationPath $destinationFile

# Provide the space name for the projects to export.
$sourceSpaceName = "<source_space_name>"
# Provide a list of project names to export.
$projectNames = @("Project 1", "Project 2")
# Provide a password for the export zip file
$exportTaskPassword = "<zip_password>"
# Wait for the export task to finish?
$exportTaskWaitForFinish = $True
# Provide a timeout for the export task to be canceled.
$exportTaskCancelInSeconds=300

# Define Target working variables
$targetOctopusURL = "https://<target_octopus_url>/"
$targetOctopusAPIKey = "API-KEY-2"

$targetHeader = @{ "X-Octopus-ApiKey" = $targetOctopusAPIKey }

# Provide the space name for the projects to be imported into.
$targetSpace = "<target_space_name>"

# Wait for the import task to finish?
$importTaskWaitForFinish = $True
# Provide a timeout for the imports task to be canceled.
$importTaskCancelInSeconds = 300


$sourceOctopusURL = $sourceOctopusURL.TrimEnd('/')
# Get Source Space
$spaces = Invoke-RestMethod -Uri "$sourceOctopusURL/api/spaces?partialName=$([uri]::EscapeDataString($sourceSpaceName))&skip=0&take=100" -Headers $sourceHeader 
$space = $spaces.Items | Where-Object { $_.Name -eq $sourceSpaceName }
$exportTaskSpaceId = $space.Id

$exportTaskProjectIds = @()

if (![string]::IsNullOrWhiteSpace($projectNames)) {
    @(($projectNames -Split "`n").Trim()) | ForEach-Object {
        if (![string]::IsNullOrWhiteSpace($_)) {
            Write-Verbose "Working on: '$_'"
            $projectName = $_.Trim()
            if ([string]::IsNullOrWhiteSpace($projectName)) {
                throw "Project name is empty'"
            }
            $projects = Invoke-RestMethod -Uri "$sourceOctopusURL/api/$($space.Id)/projects?partialName=$([uri]::EscapeDataString($projectName))&skip=0&take=100" -Headers $sourceHeader 
            $project = $projects.Items | Where-Object { $_.Name -eq $projectName }
            $exportTaskProjectIds += $project.Id
        }
    }
}

$exportBody = @{
    IncludedProjectIds = $exportTaskProjectIds;
    Password           = @{
        HasValue = $True;
        NewValue = $exportTaskPassword;
    }
}

$exportBodyAsJson = $exportBody | ConvertTo-Json
$exportBodyPostUrl = "$sourceOctopusURL/api/$($exportTaskSpaceId)/projects/import-export/export"
Write-Host "Kicking off export run by posting to $exportBodyPostUrl"
Write-Verbose "Payload: $exportBodyAsJson"
$exportResponse = Invoke-RestMethod $exportBodyPostUrl -Method POST -Headers $sourceHeader -Body $exportBodyAsJson
$exportServerTaskId = $exportResponse.TaskId
Write-Host "The task id of the new task is $exportServerTaskId"
Write-Host "Export task was successfully invoked, you can access the task: $sourceOctopusURL/app#/$exportTaskSpaceId/tasks/$exportServerTaskId"

$exportArtifact = ""

if ($exportTaskWaitForFinish -eq $true) {
    Write-Host "The setting to wait for completion was set, waiting until task has finished"
    $startTime = Get-Date
    $currentTime = Get-Date
    $dateDifference = $currentTime - $startTime
    $taskStatusUrl = "$sourceOctopusURL/api/$exportTaskSpaceId/tasks/$exportServerTaskId"
    $numberOfWaits = 0    
    While ($dateDifference.TotalSeconds -lt $exportTaskCancelInSeconds) {
        Write-Host "Waiting 5 seconds to check status"
        Start-Sleep -Seconds 5
        $taskStatusResponse = Invoke-RestMethod $taskStatusUrl -Headers $sourceHeader        
        $taskStatusResponseState = $taskStatusResponse.State
        if ($taskStatusResponseState -eq "Success") {
            Write-Host "The task has finished with a status of Success"
            $artifactsUrl = "$sourceOctopusURL/api/$exportTaskSpaceId/artifacts?regarding=$exportServerTaskId"
            Write-Host "Checking for artifacts from $artifactsUrl"
            $artifacts = Invoke-RestMethod $artifactsUrl -Method GET -Headers $sourceHeader
            $exportArtifact = $artifacts.Items | Where-Object { $_.Filename -like "Octopus-Export-*.zip" } 
            Write-Host "Export task successfully completed, you can download the export archive: $sourceOctopusURL$($exportArtifact.Links.Content)"
            break
        }
        elseif ($taskStatusResponseState -eq "Failed" -or $taskStatusResponseState -eq "Canceled") {
            Write-Host "The task has finished with a status of $taskStatusResponseState status, completing"
            exit 1            
        }
        $numberOfWaits += 1
        if ($numberOfWaits -ge 10) {
            Write-Host "The task state is currently $taskStatusResponseState"
            $numberOfWaits = 0
        }
        else {
            Write-Host "The task state is currently $taskStatusResponseState"
        }  
        $startTime = $taskStatusResponse.StartTime
        if ($null -eq $startTime -or [string]::IsNullOrWhiteSpace($startTime) -eq $true) {        
            Write-Host "The task is still queued, let's wait a bit longer"
            $startTime = Get-Date
        }
        $startTime = [DateTime]$startTime
        $currentTime = Get-Date
        $dateDifference = $currentTime - $startTime        
    } 

    if ($dateDifference.TotalSeconds -gt $exportTaskCancelInSeconds) {
        Write-Host "The cancel timeout has been reached, cancelling the export task"
        Invoke-RestMethod "$octopusURL/api/$exportTaskSpaceId/tasks/$exportTaskSpaceId/cancel" -Headers $header -Method Post | Out-Null
        Write-Host "Exiting with an error code of 1 because we reached the timeout"
        exit 1
    }

}

# Download ZIP
Write-Host "Downloading ZIP export to $destinationFilePath"
Invoke-RestMethod -Uri $sourceOctopusURL$($exportArtifact.Links.Content) -OutFile "$destinationFilePath" -Headers $sourceHeader -Method Get


$targetOctopusURL = $targetOctopusURL.TrimEnd('/')

# Get Target Space
$spaces = Invoke-RestMethod -Uri "$targetOctopusURL/api/spaces?partialName=$([uri]::EscapeDataString($targetSpace))&skip=0&take=100" -Headers $targetHeader 
$space = $spaces.Items | Where-Object { $_.Name -eq $targetSpace }
$importTaskSpaceId = $space.Id

$filePathToUpload = "$destinationFilePath"

# Upload File to Target Server
Write-Host "Preparing file upload"
Add-Type -AssemblyName System.Net.Http
$httpClientHandler = New-Object System.Net.Http.HttpClientHandler

$httpClient = New-Object System.Net.Http.HttpClient $httpClientHandler
$httpClient.DefaultRequestHeaders.Add("X-Octopus-ApiKey", $targetOctopusAPIKey)

$packageFileStream = New-Object System.IO.FileStream @($filePathToUpload, [System.IO.FileMode]::Open)

$contentDispositionHeaderValue = New-Object System.Net.Http.Headers.ContentDispositionHeaderValue "form-data"
$contentDispositionHeaderValue.Name = "fileData"
$contentDispositionHeaderValue.FileName = [System.IO.Path]::GetFileName($filePathToUpload)

$streamContent = New-Object System.Net.Http.StreamContent $packageFileStream
$streamContent.Headers.ContentDisposition = $contentDispositionHeaderValue
$ContentType = "multipart/form-data"
$streamContent.Headers.ContentType = New-Object System.Net.Http.Headers.MediaTypeHeaderValue $ContentType

$content = New-Object System.Net.Http.MultipartFormDataContent
$content.Add($streamContent)

$uploadUrl = "$targetOctopusURL/api/$importTaskSpaceId/projects/import-export/import-files"
Write-Host "Uploading file $filePathToUpload to $uploadUrl"
$httpClient.PostAsync($uploadUrl, $content).Result

# Import project

$importBody = @{
    ImportSource = @{
        Type           = "upload";
        UploadedFileId = $destinationFile;
    };
    Password     = @{
        HasValue = $True;
        NewValue = $exportTaskPassword;
    };

}


$importBodyAsJson = $importBody | ConvertTo-Json
$importBodyPostUrl = "$targetOctopusURL/api/$($importTaskSpaceId)/projects/import-export/import"
Write-Host "Kicking off import run by posting to $importBodyPostUrl"
Write-Verbose "Payload: $importBodyAsJson"
$importResponse = Invoke-RestMethod $importBodyPostUrl -Method POST -Headers $targetHeader -Body $importBodyAsJson
$importServerTaskId = $importResponse.TaskId
Write-Host "The task id of the new task is $importServerTaskId"
Write-Host "Import task was successfully invoked, you can access the task: $octopusURL/app#/$importTaskSpaceId/tasks/$importServerTaskId"

if ($importTaskWaitForFinish -eq $true) {
    Write-Host "The setting to wait for completion was set, waiting until task has finished"
    $startTime = Get-Date
    $currentTime = Get-Date
    $dateDifference = $currentTime - $startTime
    $taskStatusUrl = "$targetOctopusURL/api/$importTaskSpaceId/tasks/$importServerTaskId"
    $numberOfWaits = 0    
    While ($dateDifference.TotalSeconds -lt $importTaskCancelInSeconds) {
        Write-Host "Waiting 5 seconds to check status"
        Start-Sleep -Seconds 5
        $taskStatusResponse = Invoke-RestMethod $taskStatusUrl -Headers $targetHeader        
        $taskStatusResponseState = $taskStatusResponse.State
        if ($taskStatusResponseState -eq "Success") {
            Write-Host "The task has finished with a status of Success"
            exit 0
        }
        elseif ($taskStatusResponseState -eq "Failed" -or $taskStatusResponseState -eq "Canceled") {
            Write-Host "The task has finished with a status of $taskStatusResponseState status, completing"
            exit 1            
        }
        $numberOfWaits += 1
        if ($numberOfWaits -ge 10) {
            Write-Host "The task state is currently $taskStatusResponseState"
            $numberOfWaits = 0
        }
        else {
            Write-Host "The task state is currently $taskStatusResponseState"
        }  
        $startTime = $taskStatusResponse.StartTime
        if ($null -eq $startTime -or [string]::IsNullOrWhiteSpace($startTime) -eq $true) {        
            Write-Host "The task is still queued, let's wait a bit longer"
            $startTime = Get-Date
        }
        $startTime = [DateTime]$startTime
        $currentTime = Get-Date
        $dateDifference = $currentTime - $startTime        
    }
    Write-Host "The cancel timeout has been reached, cancelling the import task"
    Invoke-RestMethod "$targetOctopusURL/api/$importTaskSpaceId/tasks/$importTaskSpaceId/cancel" -Headers $targetHeader -Method Post | Out-Null
    Write-Host "Exiting with an error code of 1 because we reached the timeout"
    exit 1
}