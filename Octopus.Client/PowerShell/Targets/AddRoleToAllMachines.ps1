# You can get this dll from NuGet
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll'

$apikey = 'API-XXXXXXXXXXXXXXXXXXXXXX' # Get this from your profile
$octopusURI = 'https://octopus.url' # Your server address

$role = "A new role" # The role to add to each machine

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

$machines = $repository.Machines.FindAll();

foreach ($machine in $machines) {
    $machine.Roles.Add($role)
    $repository.Machines.Modify($machine)
}
