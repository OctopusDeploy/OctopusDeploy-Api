# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll' 

$apikey = 'API-xxx' # Get this from your profile
$octopusURI = 'http://localhost' # Your Octopus Server address

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

$tentacleEndpoint = New-Object Octopus.Client.Model.Endpoints.PollingTentacleEndpointResource
$tentacleEndpoint.Thumbprint = "3BE9C24663D3CE052CFF9D0591914FADB8DEAF30" # Your Octopus Server thumbprint
$tentacleEndpoint.Uri = "poll://" + (([char[]]([char]'A'..[char]'Z') | sort {get-random})[0..20] -Join '') + "/"

$tentacle = New-Object Octopus.Client.Model.MachineResource
$tentacle.Endpoint = $tentacleEndpoint
$tentacle.EnvironmentIds.Add("Environments-1") # Get this from /api/environments
$tentacle.Roles.Add("demo-role") # The role of the machine
$tentacle.Name = "Demo tentacle" # The name of the machine

$repository.Machines.Create($tentacle)
