$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"
$projectName = "Project_Name"
$runbookName = "Runbook_Name"

# Get space
$spaces = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -eq $spaceName }

# Get project
$projects = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects?partialName=$([uri]::EscapeDataString($projectName))&skip=0&take=100" -Headers $header 
$project = $projects.Items | Where-Object { $_.Name -eq $projectName }

# Get runbook
$runbooks = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/runbooks?partialName=$([uri]::EscapeDataString($runbookName))&skip=0&take=100" -Headers $header 
$runbook = $runbooks.Items | Where-Object { $_.Name -eq $runbookName }

# Get snapshots for runbook (if not all snapshots are deleted for a particular runbook, increase take=value or run the script again)
$snapshots = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/runbooks/$($runbook.Id)/runbookSnapshots?take=10000" -Headers $header

# Loop through list
foreach ($snapshot in $snapshots.Items)
{
    # Delete snapshots
    Invoke-RestMethod -Method Delete -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/runbookSnapshots/$($snapshot.Id)" -Headers $header
}
