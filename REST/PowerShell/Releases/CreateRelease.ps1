# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$projectName = "MyProject"
$channelName = "Default"
$spaceName = "default"

try
{
    # Get space
    $space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

    # Get project
    $project = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header) | Where-Object {$_.Name -eq $projectName}

    # Get deploymentProcess
    $deploymentProcess = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/deploymentprocesses/$($project.DeploymentProcessId)" -Headers $header

    # Get channel
    $channel = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/channels" -Headers $header).Items | Where-Object {$_.Name -eq $channelName}

    # Loop through the deployment process and gather selected packages
    $releaseBody = @{
        ChannelId        = $channel.Id
        ProjectId        = $project.Id
        Version          = $template.NextVersionIncrement
        SelectedPackages = @()
    }
    $template = Invoke-WebRequest -Uri "$octopusURL/api/$($space.id)/deploymentprocesses/deploymentprocess-$($project.id)/template?channel=$($channel.Id)" -Headers $header | ConvertFrom-Json

    Write-Host "Getting step package versions"
    $template.Packages | ForEach-Object {
        $uri = "$octopusURL/api/$($space.id)/feeds/$($_.FeedId)/packages/versions?packageId=$($_.PackageId)&take=1"
        $version = Invoke-WebRequest -Uri $uri -Method GET -Headers $header -Body $releaseBody -ErrorVariable octoError | ConvertFrom-Json
        $version = $version.Items[0].Version

        $releaseBody.SelectedPackages += @{
            ActionName           = $_.ActionName
            PackageReferenceName = $_.PackageReferenceName
            Version              = $version
        }
    }

    # Create release
    $releaseBody = $releaseBody | ConvertTo-Json -depth 10
    Write-Host "Creating release with these values: $releaseBody"
    $release = Invoke-WebRequest -Uri "$octopusURL/api/$($space.id)/releases" -Method POST -Headers $header -Body $releaseBody -ErrorVariable octoError | ConvertFrom-Json
}
catch
{
    Write-Host $_.Exception.Message
}
