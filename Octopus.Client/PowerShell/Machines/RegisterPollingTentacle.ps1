# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll' 

$apikey = 'API-xxx' # Get this from your profile
$octopusURI = 'http://localhost' # Your Octopus Server address

$octopusServerThumbprint = "3BE9C24663D3CE052CFF9D0591914FADB8DEAF30" # Your Octopus Server thumbprint
$environmentId = "Environments-1" # Get this from /api/environments
$role = "demo-role" # The role of the machine
$machineName = "Demo tentacle" # The name of the machine

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

$tentacleEndpoint = New-Object Octopus.Client.Model.Endpoints.PollingTentacleEndpointResource
$tentacleEndpoint.Thumbprint = $octopusServerThumbprint
$tentacleEndpoint.Uri = "poll://" + (([char[]]([char]'A'..[char]'Z') | sort {get-random})[0..20] -Join '') + "/"

$tentacle = New-Object Octopus.Client.Model.MachineResource
$tentacle.Endpoint = $tentacleEndpoint
$tentacle.EnvironmentIds.Add($environmentId) 
$tentacle.Roles.Add($role) 
$tentacle.Name = $machineName

$repository.Machines.Create($tentacle)
