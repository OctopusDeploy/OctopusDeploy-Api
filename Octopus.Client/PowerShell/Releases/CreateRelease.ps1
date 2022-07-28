# You can get this dll from NuGet
# https://www.nuget.org/packages/Octopus.Client/
# Load octopus.client assembly
Add-Type -Path "path\to\Octopus.Client.dll"

# Octopus variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$spaceName = "default"
$projectName = "MyProject"
$channelName = "default"
$releaseVersion = "1.0.0.0"

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURL, $octopusAPIKey
$repository = New-Object Octopus.Client.OctopusRepository $endpoint
$client = New-Object Octopus.Client.OctopusClient $endpoint

try
{
    # Get space+repo
    $space = $repository.Spaces.FindByName($spaceName)
    $repositoryForSpace = $client.ForSpace($space)

    # Get project
    $project = $repositoryForSpace.Projects.FindByName($projectName)

    # Get channel
    $channel = $repositoryForSpace.Channels.FindOne({param($c) $c.Name -eq $channelName -and $c.ProjectId -eq $project.Id})

    # Create a new release resource
    $release = New-Object Octopus.Client.Model.ReleaseResource
    $release.ChannelId = $channel.Id
    $release.ProjectId = $project.Id
    $release.Version = $releaseVersion
    $release.SelectedPackages = New-Object 'System.Collections.Generic.List[Octopus.Client.Model.SelectedPackage]'

    # Get deployment process
    $deploymentProcess = $repositoryForSpace.DeploymentProcesses.Get($project.DeploymentProcessId)

    # Get template
    $template = $repositoryForSpace.DeploymentProcesses.GetTemplate($deploymentProcess, $channel)

    # Loop through the deployment process packages and add to release payload
    $template.Packages | ForEach-Object {
        # Get feed 
        $feed = $repositoryForSpace.Feeds.Get($package.FeedId)
        $packageIds = @($package.PackageId)
        $version = ($repositoryForSpace.Feeds.GetVersions($feed,$packageIds) | Select-Object -First 1).Version
        $selectedPackage = New-Object Octopus.Client.Model.SelectedPackage
        $selectedPackage.ActionName = $_.ActionName
        $selectedPackage.PackageReferenceName = $_.PackageReferenceName
        $selectedPackage.Version = $version

        # Add to release
        $release.SelectedPackages.Add($selectedPackage)
    }

    # Create the release
    $releaseCreated = $repositoryForSpace.Releases.Create($release, $false)

    # Display created release
    $releaseCreated
}
catch
{
    Write-Host $_.Exception.Message
}