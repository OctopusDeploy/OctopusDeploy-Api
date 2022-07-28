# You can get this dll from NuGet
# https://www.nuget.org/packages/Octopus.Client/
# Load octopus.client assembly
Add-Type -Path "path\to\Octopus.Client.dll"

# Octopus variables
$octopusURL = "https://youroctourl/api"
$octopusAPIKey = "API-YOURAPIKEY"
$spaceName = "default"
$role = "MyRole"

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURL, $octopusAPIKey
$repository = New-Object Octopus.Client.OctopusRepository $endpoint
$client = New-Object Octopus.Client.OctopusClient $endpoint

try
{
    # Get space
    $space = $repository.Spaces.FindByName($spaceName)
    $repositoryForSpace = $client.ForSpace($space)

    # Get machine list
    $machines = $repositoryForSpace.Machines.GetAll() | Where-Object {$role -in $_.Roles}

    # Loop through list
    foreach ($machine in $machines)
    {
        # Delete machine
        $repositoryForSpace.Machines.Delete($machine)
    }
}
catch
{
    Write-Host $_.Exception.Message
}