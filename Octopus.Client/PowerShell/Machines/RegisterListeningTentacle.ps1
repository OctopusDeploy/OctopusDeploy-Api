# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll' 

$apikey = 'API-xxx' # Get this from your profile
$octopusURI = 'http://localhost' # Your Octopus Server address

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

$tentacleEndpoint = New-Object Octopus.Client.Model.EndPoints.ListeningTentacleEndpointResource
$tentacleEndpoint.Thumbprint = "551290ED75D2A4AEBBB6F31778DB1C0D4865B091" # Your Octopus Server thumbprint
$tentacleEndpoint.Uri = "https://localhost:10933" # Your Tentacle address

$tentacle = New-Object Octopus.Client.Model.MachineResource
$tentacle.Endpoint = $tentacleEndpoint
$tentacle.EnvironmentIds.Add("Environments-1") # Get this from /api/environments
$tentacle.Roles.Add("demo-role") # The role for this machine
$tentacle.Name = "Demo tentacle" # The name of this machine

$repository.Machines.Create($tentacle)
