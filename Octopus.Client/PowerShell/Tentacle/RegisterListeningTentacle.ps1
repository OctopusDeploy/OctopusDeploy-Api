Add-Type -Path 'Octopus.Client.dll' 

$apikey = 'API-xxx' 
$OctopusURI = 'http://localhost'

$endpoint = new-object Octopus.Client.OctopusServerEndpoint $OctopusURI,$apikey 
$repository = new-object Octopus.Client.OctopusRepository $endpoint

$tentacleEndpoint = New-Object Octopus.Client.Model.EndPoints.ListeningTentacleEndpointResource
$tentacleEndpoint.Thumbprint = "551290ED75D2A4AEBBB6F31778DB1C0D4865B091"
$tentacleEndpoint.Uri = "https://localhost:10933"

$tentacle = New-Object Octopus.Client.Model.MachineResource
$tentacle.Endpoint = $tentacleEndpoint
$tentacle.EnvironmentIds.Add("Environments-1")
$tentacle.Roles.Add("demo-role")
$tentacle.Name = "Tentacle from client"

$repository.Machines.Create($tentacle)
