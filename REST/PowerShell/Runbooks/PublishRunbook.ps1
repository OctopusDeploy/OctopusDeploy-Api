# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"
$projectName = "MyProject"
$runbookName = "MyRunbook"
$snapshotName = "Snapshot 9PNENH6"

try
{
    # Get space
    $space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

    # Get project
    $project = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header) | Where-Object {$_.Name -eq $projectName}
    
    # Get runbook
    $runbook = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/runbooks" -Headers $header).Items | Where-Object {$_.Name -eq $runbookName}
    
    # Get the runbook process
    $runbookSnapshot = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/runbookSnapshots" -Headers $header).Items | Where-Object {$_.Name -eq $snapshotName}
    
    # Publish the snapshot
    $runbook.PublishedRunbookSnapshotId = $runbookSnapshot.Id
    Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/runbooks/$($runbook.Id)" -Body ($runbook | ConvertTo-Json -Depth 10) -Headers $header
}
catch
{
    Write-Host $_.Exception.Message
}