# Load assembly
Add-Type -Path 'path:\to\Octopus.Client.dll'
$octopusURL = "https://YourURL"
$octopusAPIKey = "API-YourAPIKey"
$spaceName = "Default"
$projectGroupName = "MyProjectGroup"
$projectGroupDescription = "MyDescription"

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint($octopusURL, $octopusAPIKey)
$repository = New-Object Octopus.Client.OctopusRepository($endpoint)
$client = New-Object Octopus.Client.OctopusClient($endpoint)

# Get space
$space = $repository.Spaces.FindByName($spaceName)
$repositoryForSpace = $client.ForSpace($space)

# Create project group object
$projectGroup = New-Object Octopus.Client.Model.ProjectGroupResource
$projectGroup.Description = $projectGroupDescription
$projectGroup.Name = $projectGroupName
$projectGroup.EnvironmentIds = $null
$projectGroup.RetentionPolicyId = $null

$repositoryForSpace.ProjectGroups.Create($projectGroup)