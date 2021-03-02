$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"
$projectName = "MyProject"
$runbookName = "MyRunbook"

# Get space
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -eq $spaceName }

# Get project
$projects = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/projects?partialName=$([uri]::EscapeDataString($projectName))&skip=0&take=100" -Headers $header 
$project = $projects.Items | Where-Object { $_.Name -eq $projectName }

# Get runbook
$runbooks = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/runbooks?partialName=$([uri]::EscapeDataString($runbookName))&skip=0&take=100" -Headers $header 
$runbook = $runbooks.Items | Where-Object { $_.Name -eq $runbookName }

# Get a runbook snapshot template
$runbookSnapshotTemplate = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/runbookProcesses/$($runbook.RunbookProcessId)/runbookSnapshotTemplate" -Headers $header 

# Create a runbook snapshot
$body = @{
    ProjectId = $project.Id
    RunbookId = $runbook.Id
    Name = $runbookSnapshotTemplate.NextNameIncrement
    Notes = $null
    SelectedPackages = @()
}

# Include latest built-in feed packages
foreach($package in $runbookSnapshotTemplate.Packages)
{
    if($package.FeedId -eq "feeds-builtin") {
        # Get latest package version
        $packages = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/feeds/feeds-builtin/packages/versions?packageId=$($package.PackageId)&take=1" -Headers $header 
        $latestPackage = $packages.Items | Select-Object -First 1
        $package = @{
            ActionName = $package.ActionName
            Version = $latestPackage.Version
            PackageReferenceName = $package.PackageReferenceName
        }
        
        $body.SelectedPackages += $package
    }
}

$body = $body | ConvertTo-Json -Depth 10
$runbookPublishedSnapshot = Invoke-RestMethod -Method Post -Uri "$octopusURL/api/$($space.Id)/runbookSnapshots?publish=true" -Body $body -Headers $header 

# Re-get runbook
$runbook = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/runbooks/$($runbook.Id)" -Headers $header 

# Publish the snapshot
$runbook.PublishedRunbookSnapshotId = $runbookPublishedSnapshot.Id
Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/runbooks/$($runbook.Id)" -Body ($runbook | ConvertTo-Json -Depth 10) -Headers $header

Write-Host "Published runbook snapshot: $($runbookPublishedSnapshot.Id) ($($runbookPublishedSnapshot.Name))"