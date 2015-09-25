Add-Type -Path 'Octopus.Client.dll' 

$apikey = 'API-xxx' 
$octopusURI = 'http://localhost'

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

$tentacleEndpoint = New-Object Octopus.Client.Model.EndPoints.ListeningTentacleEndpointResource
$tentacleEndpoint.Thumbprint = "551290ED75D2A4AEBBB6F31778DB1C0D4865B091"
$tentacleEndpoint.Uri = "https://localhost:10933"

$tentacle = New-Object Octopus.Client.Model.MachineResource
$tentacle.Endpoint = $tentacleEndpoint
$tentacle.EnvironmentIds.Add("Environments-1")
$tentacle.Roles.Add("demo-role")
$tentacle.Name = "Tentacle from client"

$repository.Machines.Create($tentacle)
