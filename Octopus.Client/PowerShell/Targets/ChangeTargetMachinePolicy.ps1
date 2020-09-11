# You can get this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
# Load octopus.client assembly
Add-Type -Path "c:\octopus.client\Octopus.Client.dll"

# Octopus variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$spaceName = "default"
$machineName = "MyMachine"
$machinePolicyName = "MyPolicy"

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURL, $octopusAPIKey
$repository = New-Object Octopus.Client.OctopusRepository $endpoint
$client = New-Object Octopus.Client.OctopusClient $endpoint

try
{
    # Get space
    $space = $repository.Spaces.FindByName($spaceName)
    $repositoryForSpace = $client.ForSpace($space)

    # Get machine list
    $machine = $repositoryForSpace.Machines.FindByName($machineName)

    # Get machine policy
    $machinePolicy = $repositoryForSpace.MachinePolicies.FindByName($machinePolicyName)

    # Change machine policy for machine
    $machine.MachinePolicyId = $machinePolicy.Id
    $repositoryForSpace.Machines.Modify($machine)
}
catch
{
    Write-Host $_.Exception.Message
}