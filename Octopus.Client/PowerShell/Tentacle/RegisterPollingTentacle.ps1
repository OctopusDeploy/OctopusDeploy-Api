Add-Type -Path 'Octopus.Client.dll' 

$apikey = 'API-MCPLE1AQM2VKTRFDLIBMORQHBXA' 
$octopusURI = 'http://localhost'

$endpoint = new-object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = new-object Octopus.Client.OctopusRepository $endpoint

$tentacleEndpoint = New-Object Octopus.Client.Model.Endpoints.PollingTentacleEndpointResource
$tentacleEndpoint.Thumbprint = "3BE9C24663D3CE052CFF9D0591914FADB8DEAF30"
$tentacleEndpoint.Uri = "poll://" + (([char[]]([char]'A'..[char]'Z') | sort {get-random})[0..20] -Join '') + "/"

$tentacle = New-Object Octopus.Client.Model.MachineResource
$tentacle.Endpoint = $tentacleEndpoint
$tentacle.EnvironmentIds.Add("Environments-1")
$tentacle.Roles.Add("demo-role")
$tentacle.Name = "Demo tentacle"

$repository.Machines.Create($tentacle)
