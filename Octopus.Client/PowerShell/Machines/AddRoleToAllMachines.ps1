# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll' 

$apikey = 'API-RASSW3YNB6FJL3FNWBSSUUCX0C' # Get this from your profile
$octopusURI = 'http://localhost:8065' # Your server address

$role = "A new role" # The role to add to each machine

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

$machines = $repository.Machines.FindAll();

foreach ($machine in $machines) {
    $machine.Roles.Add($role)
    $repository.Machines.Modify($machine)
}
