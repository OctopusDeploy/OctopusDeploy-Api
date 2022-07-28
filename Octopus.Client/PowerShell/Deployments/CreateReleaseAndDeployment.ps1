# You can get this dll from NuGet
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'path\to\Octopus.Client.dll'

$octopusBaseURL = "https://youroctourl/"
$octopusAPIKey = "API-YOURAPIKEY"

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint($octopusBaseURL, $octopusAPIKey)
$repository = New-Object Octopus.Client.OctopusRepository($endpoint)

$spaceName = "Default"
$projectName = "Your Project Name"
$channelName = "Default"
$environmentName = "Dev"

try {
    # Get space id
    $space = $repository.Spaces.FindByName($spaceName)
    Write-Host "Using Space named $($space.Name) with id $($space.Id)"

    # Create space specific repository
    $repositoryForSpace = [Octopus.Client.OctopusRepositoryExtensions]::ForSpace($repository, $space)

    # Get project by name
    $project = $repositoryForSpace.Projects.FindByName($projectName)
    Write-Host "Using Project named $($project.Name) with id $($project.Id)"

    # Get channel by name
    $channel = $repositoryForSpace.Channels.FindByName($project, $channelName)
    Write-Host "Using Channel named $($channel.Name) with id $($channel.Id)"

    # Get environment by name
    $environment = $repositoryForSpace.Environments.FindByName($environmentName)
    Write-Host "Using Environment named $($environment.Name) with id $($environment.Id)"

    # Get the deployment process template
    Write-Host "Fetching deployment process template"
    $process = $repositoryForSpace.DeploymentProcesses.Get($project.DeploymentProcessId)
    $template = $repositoryForSpace.DeploymentProcesses.GetTemplate($process, $channel)

    Write-Host "Creating release for $projectName"
    $release = New-Object Octopus.Client.Model.ReleaseResource -Property @{
        ChannelId = $channel.Id
        ProjectId = $project.Id
        Version   = $template.NextVersionIncrement
    }

    # Set the package version to the latest for each package
    # If you have channel rules that dictate what versions can be used,
    #  you'll need to account for that by overriding the package version
    Write-Host "Getting action package versions"
    $template.Packages | ForEach-Object {
        $feed = $repositoryForSpace.Feeds.Get($_.FeedId)
        $latestPackage = [Linq.Enumerable]::FirstOrDefault($repositoryForSpace.Feeds.GetVersions($feed, @($_.PackageId)))

        $selectedPackage = New-Object Octopus.Client.Model.SelectedPackage -Property @{
            ActionName = $_.ActionName
            Version    = $latestPackage.Version
        }

        Write-Host "Using version $($latestPackage.Version) for action $($_.ActionName) package $($_.PackageId)"

        $release.SelectedPackages.Add($selectedPackage)
    }

    # Create release
    $release = $repositoryForSpace.Releases.Create($release, $false) # pass in $true if you want to ignore channel rules

    # Create deployment
    $deployment = New-Object Octopus.Client.Model.DeploymentResource -Property @{
        ReleaseId     = $release.Id
        EnvironmentId = $environment.Id
    }

    Write-Host "Creating deployment for release $($release.Version) of project $projectName to environment $environmentName"
    $deployment = $repositoryForSpace.Deployments.Create($deployment)
}
catch {
    Write-Host $_.Exception.Message
    exit
}