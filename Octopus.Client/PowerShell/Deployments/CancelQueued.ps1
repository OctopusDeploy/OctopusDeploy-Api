$apikey = 'XXXXXX' # Get this from your profile
$OctopusUrl = 'https://OctopusURL/' # Your Octopus Server address
$spaceName = "Default" # Name of the Space
$projectId = "ProjectID" # Get this from the URL when you have browsed to the project i.e https://OctopusURL/app#/Spaces-42/projects/project10/deployments becomes project10

# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/

Add-Type -Path 'Octopus.Client.dll'

# Set up endpoint and Spaces repository
$endpoint = new-object Octopus.Client.OctopusServerEndpoint $OctopusUrl, $APIKey
$client = new-object Octopus.Client.OctopusClient $endpoint

# Find Space
$space = $client.ForSystem().Spaces.FindByName($spaceName)
$spaceRepository = $client.ForSpace($space)

# Kill Tasks
$deployments = $spaceRepository.Deployments.FindAll() 
$queued = $spaceRepository.Tasks.FindAll() | Where-Object {$_.State -eq "Queued" -and $_.HasBeenPickedUpByProcessor -eq $false}
foreach ($task in $queued)
{
    Write-Output "Killing task $($task.Id)"
    $spaceRepository.Tasks.Cancel($task)
}
