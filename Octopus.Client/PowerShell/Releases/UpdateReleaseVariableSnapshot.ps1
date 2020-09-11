# You can get this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll' 

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

    # Get channel
    $channel = $repositoryForSpace.Channels.FindOne({param($c) $c.Name -eq $channelName -and $c.ProjectId -eq $project.Id})

    # Get the release
    $release = $repositoryForSpace.Releases.FindOne({param($r) $r.ChannelId -eq $channel.Id -and $r.ProjectId -eq $project.Id -and $r.Version -eq $releaseVersion})
    
    # Get new variable snapshot
    $repositoryForSpace.Releases.SnapshotVariables($release)
}
catch
{
    Write-Host $_.Exception.Message
}