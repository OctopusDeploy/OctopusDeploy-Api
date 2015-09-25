# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll' 

$apikey = 'API-MCPLE1AQM2VKTRFDLIBMORQHBXA' # Get this from your profile
$octopusURI = 'http://localhost' # Your server address

$endpoint = new-object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = new-object Octopus.Client.OctopusRepository $endpoint

$teamId = "Teams-1" # Get this from /api/teams
$environmentId = "Environments-1" # Get this from /api/environments

$team = $repository.Teams.Get($teamID)

$team.EnvironmentIds.Add($environmentId)

$repository.Teams.Modify($team)
