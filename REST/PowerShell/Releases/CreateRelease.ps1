$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$projectName = "MyProject"
$releaseVersion = "1.0.0.0"
$channelName = "Default"
$spaceName = "default"

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get project
$project = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header) | Where-Object {$_.Name -eq $projectName}

# Get channel
$channel = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/channels" -Headers $header).Items | Where-Object {$_.Name -eq $channelName}

# Create release payload
$releaseBody = @{
    ChannelId        = $channel.Id
    ProjectId        = $project.Id
    Version          = $releaseVersion
    SelectedPackages = @()
}

# Get deployment process template
$template = Invoke-RestMethod -Uri "$octopusURL/api/$($space.id)/deploymentprocesses/deploymentprocess-$($project.id)/template?channel=$($channel.Id)" -Headers $header

# Loop through the deployment process packages and add to release payload
$template.Packages | ForEach-Object {
    $uri = "$octopusURL/api/$($space.id)/feeds/$($_.FeedId)/packages/versions?packageId=$($_.PackageId)&take=1"
    $version = Invoke-RestMethod -Uri $uri -Method GET -Headers $header
    $version = $version.Items[0].Version

    $releaseBody.SelectedPackages += @{
        ActionName           = $_.ActionName
        PackageReferenceName = $_.PackageReferenceName
        Version              = $version
    }
}

# Create the release
$release = Invoke-RestMethod -Uri "$octopusURL/api/$($space.id)/releases" -Method POST -Headers $header -Body ($releaseBody | ConvertTo-Json -depth 10)

# Display created release
$release