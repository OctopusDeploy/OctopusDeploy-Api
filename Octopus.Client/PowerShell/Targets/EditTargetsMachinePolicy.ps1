# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/

Add-Type -Path 'C:\MyScripts\Octopus.Client\Octopus.Client.dll' 

$apikey = 'API-MCPLE1AQM2VKTRFDLIBMORQHBXA' # Get this from your profile
$octopusURI = 'http://OCTOSVR/' # Your Octopus Server address

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI, $apiKey
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

$newMachinePolicy = "MachinePolicies-1" # The machine policy you wish to add to the targets (Find this in the URL when viewing the Machine Policy) Example: http://OCTOSVR/app#/infrastructure/machinepolicies/MachinePolicies-1

$machineToEdit = "Machines-41" # The machine you wish to add the Machine Policy to (Find this in the URL when viewing the Machine) http://OCTOSVR/app#/infrastructure/machines/Machines-41/settings

$machine = $repository.Machines.Get($machineToEdit) # Get target machine you want to edit

$machine.MachinePolicyId = $newMachinePolicy # Update the MachinePolicyId property for returned machine

$repository.Machines.Modify($machine) # Apply the updated MachinePolicyId value to the Machine
