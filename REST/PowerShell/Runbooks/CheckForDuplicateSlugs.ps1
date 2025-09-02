#This a modification to checking for blank slugs to check for duplicate ones when converting Runbooks to version control
$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://YOUR-OCTOPUS-URL"
$octopusAPIKey = "API-APIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"
$projectName = "Project Name"

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get project
$project = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header) | Where-Object {$_.Name -eq $projectName}

# All Get runbooks
$runbookCount = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/runbooks" -Headers $header).TotalResults
$runbookList = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/runbooks?take=$($runbookCount)" -Headers $header).Items

#Get snapshot and frozen process for that snapshot, loop through each action, and try to add slug to hash table for the runbook. 
#This will fail if slug already exists and print out to the console
foreach($runbook in $runbookList)
{
    $slugTable = @{}
    $runbookSnapshot = (Invoke-RestMethod -Method Get -Uri "$octopusUrl/api/$($space.Id)/runbooksnapshots/$($runbook.PublishedRunbookSnapshotId)" -Headers $header)
    $runbookFrozenProcess = (Invoke-RestMethod -Method Get -Uri "$octopusUrl/$($runbookSnapshot.Links.FrozenRunbookProcess)" -Headers $header)
    foreach($action in $runbookFrozenProcess.Steps.Actions)
    {        
        try
        {
            $slugTable.Add($action.Slug, $runbook.Name)     
        }
        catch
        {
            Write-Host "[DUPE ERROR] Slug: $($action.Slug), Runbook: $($runbook.Name), Step: $($action.Name)"
        }
    }
}
