# Load assembly
Add-Type -Path 'path:\to\Octopus.Client.dll'
$octopusURL = "https://YourURL"
$octopusAPIKey = "API-YourAPIKey"
$spaceName = "Default"
$lifecycleName = "MyLifecycle"

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint($octopusURL, $octopusAPIKey)
$repository = New-Object Octopus.Client.OctopusRepository($endpoint)
$client = New-Object Octopus.Client.OctopusClient($endpoint)

# Get space
$space = $repository.Spaces.FindByName($spaceName)
$repositoryForSpace = $client.ForSpace($space)

# Check to see if lifecycle already exists
if ($null -eq $repositoryForSpace.Lifecycles.FindByName($lifecycleName))
{
    # Create new lifecyle
    $lifecycle = New-Object Octopus.Client.Model.LifecycleResource
    $lifecycle.Name = $lifecycleName
    $repositoryForSpace.Lifecycles.Create($lifecycle)
}
else
{
    Write-Host "$lifecycleName already exists."
}