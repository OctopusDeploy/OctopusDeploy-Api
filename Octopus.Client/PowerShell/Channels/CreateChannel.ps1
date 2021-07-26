# You can get this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
# Load Octopus Client assembly
Add-Type -Path 'path\to\Octopus.Client.dll' 

$octopusURL = "https://YourUrl"
$octopusAPIKey = "API-YourAPIKey"
$spaceName = "Default"
$projectName = "MyProject"
$channelName = "NewChannel"

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint($octopusURL, $octopusAPIKey)
$repository = New-Object Octopus.Client.OctopusRepository($endpoint)
$client = New-Object Octopus.Client.OctopusClient($endpoint)

# Get space
$space = $repository.Spaces.FindByName($spaceName)
$repositoryForSpace = $client.ForSpace($space)

# Get project
$project = $repositoryForSpace.Projects.FindByName($projectName)

# Createw new channel object
$channel = New-Object Octopus.Client.Model.ChannelResource
$channel.Name = $channelName
$channel.ProjectId = $project.Id
$channel.SpaceId = $space.Id

# Add channel
$repositoryForSpace.Channels.Create($channel)
