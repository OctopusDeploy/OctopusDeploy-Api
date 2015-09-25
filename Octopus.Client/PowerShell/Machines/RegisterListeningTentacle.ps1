# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll' 

$apikey = 'API-xxx' # Get this from your profile
$octopusURI = 'http://localhost' # Your Octopus Server address

$octopusServerThumbprint = "551290ED75D2A4AEBBB6F31778DB1C0D4865B091" # Your Octopus Server thumbprint
$tentacleUri = "https://localhost:10933" # Your Tentacle address
$environmentId = "Environments-1" # Get this from /api/environments
$role = "demo-role" # The role for this machine
$machineName = "Demo tentacle" # The name of this machine

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

$tentacleEndpoint = New-Object Octopus.Client.Model.EndPoints.ListeningTentacleEndpointResource
$tentacleEndpoint.Thumbprint = $octopusServerThumbprint
$tentacleEndpoint.Uri = $tentacleUri

$tentacle = New-Object Octopus.Client.Model.MachineResource
$tentacle.Endpoint = $tentacleEndpoint
$tentacle.EnvironmentIds.Add($environmentId) 
$tentacle.Roles.Add($role) 
$tentacle.Name = $machineName

$repository.Machines.Create($tentacle)
