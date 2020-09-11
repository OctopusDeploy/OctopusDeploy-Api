# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$projectName = "MyProject"
$releaseVersion = "1.0.0.0"
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
    $selectedPackages = @()
    foreach ($step in $deploymentProcess.Steps)
    {
        # Loop through the actions
        foreach($action in $step.Actions)
        {
            # Check for packages
            if ($null -ne $action.Packages)
            {
                # Loop through packages
                foreach ($package in $action.Packages)
                {
                    # Get latest version of package
                    $packageVersion = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/feeds/$($package.FeedId)/packages/versions?packageId=$($package.PackageId)&take=1" -Headers $header).Items[0].Version

                    # Add package to selected packages
                    $selectedPackages += @{
                        ActionName = $action.Name
                        Version = $packageVersion
                        PackageReferenceName = $package.PackageId
                    }
                }
            }
        }
    }

    # Create json payload
    $jsonPayload = @{
        ProjectId = $project.Id
        ChannelId = $channel.Id
        Version = $releaseVersion
        SelectedPackages = $selectedPackages
    }

    # Create the release
    Invoke-RestMethod -Method Post -Uri "$octopusURL/api/$($space.Id)/releases" -Body ($jsonPayload | ConvertTo-Json -Depth 10) -Headers $header
}
catch
{
    Write-Host $_.Exception.Message
}