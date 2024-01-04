$Whatif = $true #set to $true for a dry run where no changes are committed, set to $false to commit changes

$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"
$projectName = "MyProject"
$channelName = "MyChannel"

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get project
$project = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header) | Where-Object {$_.Name -eq $projectName}

# Get channel
$channelsList = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/$($project.id)/channels" -Headers $header)
$channel = $channelsList.items | Where-Object {$_.Name -eq $channelName}

# Get releases for project/channel combination
$releases = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/channels/$($channel.id)/releases" -Headers $header)

# Loop through list
foreach ($release in $releases.Items)
{
    # Delete release
    Write-Host "Found $($release.id) in the project `"$($project.name)`" associated with channel `"$($channel.name)`""
    if (!$Whatif) {
        Write-Host "Deleting $($release.id) ..."
        Invoke-RestMethod -Method Delete -Uri "$octopusURL/api/$($space.Id)/releases/$($release.Id)" -Headers $header
    }
}