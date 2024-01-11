$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$projectName = "MyProject"
$releaseVersion = "1.0.0.0"
$channelName = "Default"
$spaceName = "default"
# Optional for version-controlled projects
$branchName = ""

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get project
$project = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header) | Where-Object {$_.Name -eq $projectName}

# Get channel
$channel = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/channels" -Headers $header).Items | Where-Object {$_.Name -eq $channelName}

# Create release payload
$releaseBody = @{
    ChannelId               = $channel.Id
    ProjectId               = $project.Id
    Version                 = $releaseVersion
    VersionControlReference = $null
    SelectedPackages        = @()
}

# Check if project is Config-as-Code
if ($project.IsVersionControlled) {
    if ([string]::IsNullOrWhitespace($branchName)) {
        Write-Output "BranchName is not provided. Looking up default branch"
        # Get default Git branch for Config-as-Code project
        $branchName = $project.PersistenceSettings.DefaultBranch
    }
    # Get canonical branch name
    $projectBranch = Invoke-RestMethod -Uri "$octopusURL/api/$($space.id)/projects/$($project.id)/git/branches/$branchName" -Headers $header
    $templateLink = $octopusURL + $projectBranch.Links.ReleaseTemplate -Replace "{\?channel,releaseId}", "?channel=$($channel.Id)"

    # Set release gitref
    $releaseBody.VersionControlReference = @{
        GitRef = $projectBranch.CanonicalName
    }
}
else {
    $templateLink = "$octopusURL/api/$($space.id)/deploymentprocesses/deploymentprocess-$($project.id)/template?channel=$($channel.Id)"
}

# Get deployment process template
$template = Invoke-RestMethod -Uri $templateLink -Headers $header

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