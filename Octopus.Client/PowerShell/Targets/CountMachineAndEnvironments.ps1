$apikey = 'XXXXXX' # Get this from your profile
$OctopusUrl = 'https://OctopusURL/' # Your Octopus Server address
$spaceName = "Default" # Name of the Space
​
# You can get this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
​
Add-Type -Path 'Octopus.Client.dll'
​
# Set up endpoint and Spaces repository
$endpoint = new-object Octopus.Client.OctopusServerEndpoint $OctopusUrl, $APIKey
$client = new-object Octopus.Client.OctopusClient $endpoint
​
# Find Space
$space = $client.ForSystem().Spaces.FindByName($spaceName)
$spaceRepository = $client.ForSpace($space)
​
# Get Counts
$environments = $spaceRepository.Environments.FindAll()
$envCount = $environments.Count
$machines = $spaceRepository.Machines.FindAll() 
$machineCount = $machines.Count
$projects = $spaceRepository.Projects.FindAll() 
$projCount = $projects.Count
​
Write-Output "Space '$spaceName' has Environment count: $envCount"
Write-Output "Space '$spaceName' has Machine count: $machineCount"
Write-Output "Space '$spaceName' has Project count: $projCount"