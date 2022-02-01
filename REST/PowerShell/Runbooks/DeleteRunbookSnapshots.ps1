$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"
$projectName = "Project_Name"
$runbookname = "Runbook_Name"

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get project
$project = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header) | Where-Object {$_.Name -eq $projectName}

# Get runbook
$runbook = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/runbooks/all" -Headers $header) | Where-Object {($_.Name -eq $runbookname) -and ($_.ProjectId -eq $($project.Id))}

# Get snapshots for runbook (if not all snapshots are deleted for a particular runbook, increase take=value or run the script again)
$snapshots = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/runbooks/$($runbook.Id)/runbookSnapshots?take=10000" -Headers $header

# Loop through list
foreach ($snapshot in $snapshots.Items)
{
    # Delete snapshots
    Invoke-RestMethod -Method Delete -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/runbookSnapshots/$($snapshot.Id)" -Headers $header
}
