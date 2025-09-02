$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://YOUR-OCTOPUS-URL"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"
$projectName = "ProjectName"

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get project
$project = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header) | Where-Object {$_.Name -eq $projectName}

# All Get runbooks
$runbookCount = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/runbooks" -Headers $header).TotalResults
$runbookList = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/runbooks?take=$($runbookCount)" -Headers $header).Items

#Get snapshot and frozen process for that snapshot, loop through each action, and check if the slug is null or empty
foreach($runbook in $runbookList)
{
    $runbookSnapshot = (Invoke-RestMethod -Method Get -Uri "$octopusUrl/api/$($space.Id)/runbooksnapshots/$($runbook.PublishedRunbookSnapshotId)" -Headers $header)
    $runbookFrozenProcess = (Invoke-RestMethod -Method Get -Uri "$octopusUrl/$($runbookSnapshot.Links.FrozenRunbookProcess)" -Headers $header)
    foreach($action in $runbookFrozenProcess.Steps.Actions)
    {
        if([String]::IsNullOrWhitespace($action.Slug))
        {
            Write-Host "Empty slug in runbook: $($runbook.Name)"
        }
    }
}
