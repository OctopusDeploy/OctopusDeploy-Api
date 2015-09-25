$apikey = 'API-MCPLE1AQM2VKTRFDLIBMORQHBXA' # Get this from your profile
$octopusURI = 'http://localhost' # Your server address

$endpoint = new-object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = new-object Octopus.Client.OctopusRepository $endpoint

$teamId = "Teams-1" # Get this from /api/teams
$environmentId = "Environments-1" # Get this from /api/environments

$team = $repository.Teams.Get($teamID)

$team.EnvironmentIds.Add($environmentId)

$repository.Teams.Modify($team)
