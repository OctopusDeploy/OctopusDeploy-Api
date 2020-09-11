# You can get this dll from your Octopus Server/Tentacle installation directory or from
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
    # Get space
    $space = $repository.Spaces.FindByName($spaceName)
    $repositoryForSpace = $client.ForSpace($space)

    # Get project
    $project = $repositoryForSpace.Projects.FindByName($projectName)

    # Get deployment process
    $deploymentProcess = $repositoryForSpace.DeploymentProcesses.Get($project.DeploymentProcessId)

    # Get channel
    $channel = $repositoryForSpace.Channels.FindOne({param($c) $c.Name -eq $channelName -and $c.ProjectId -eq $project.Id})

    # Gather selected packages
    $selectedPackages = @()
    foreach ($step in $deploymentProcess.Steps)
    {
        # Loop through actions
        foreach ($action in $step.Actions)
        {
            # Check for package
            if ($null -ne $action.Packages)
            {
                # Loop through packages
                foreach ($package in $action.Packages)
                {
                    # Get feed
                    $feed = $repositoryForSpace.Feeds.Get($package.FeedId)

                    # Check to see if it's the built in
                    if ($feed.FeedType -eq [Octopus.Client.Model.FeedType]::BuiltIn)
                    {
                        # Get the package version
                        $packageVersion = $repositoryForSpace.BuiltInPackageRepository.ListPackages($package.PackageId).Items[0].Version

                        # Create selected package pobject
                        $selectedPackage = New-Object Octopus.Client.Model.SelectedPackage
                        $selectedPackage.ActionName = $action.Name
                        $selectedPackage.PackageReferenceName = $package.PackageId
                        $selectedPackage.Version = $packageVersion

                        # Add to collection
                        $selectedPackages += $selectedPackage
                    }
                }
            }
        }
    }

    # Create a new release resource
    $release = New-Object Octopus.Client.Model.ReleaseResource
    $release.ChannelId = $channel.Id
    $release.ProjectId = $project.Id
    $release.Version = $releaseVersion

    # Add selected packages
    foreach ($selectedPackage in $selectedPackages)
    {
        $release.SelectedPackages.Add($selectedPackage)
    }

    # Create release
    $repositoryForSpace.Releases.Create($release, $false)
}
catch
{
    Write-Host $_.Exception.Message
}