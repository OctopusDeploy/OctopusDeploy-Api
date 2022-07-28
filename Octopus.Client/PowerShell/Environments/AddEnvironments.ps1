$ErrorActionPreference = "Stop";

# You can get this dll from NuGet
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'path\to\Octopus.Client.dll'

$octopusURL = "https://youroctopus.octopus.app"
$octopusAPIKey = "API-YOURAPIKEY"

$spaceName = "Default"
$environments = @("Development", "Test", "Staging", "Production")

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint($octopusURL, $octopusAPIKey)
$repository = New-Object Octopus.Client.OctopusRepository($endpoint)
$client = New-Object Octopus.Client.OctopusClient($endpoint)

# Get space
$space = $repository.Spaces.FindByName($spaceName)
$repositoryForSpace = $client.ForSpace($space)

foreach ($environmentName in $environments) {
    
    $environment = $repositoryForSpace.Environments.FindByName($environmentName)
    if($null -ne $environment) {
        Write-Host "Environment '$environmentName' already exists. Nothing to create :)"
    }
    else {
        Write-Host "Creating environment '$environmentName'"
        $environment = New-Object Octopus.Client.Model.EnvironmentResource -Property @{
            Name = $environmentName
        }
        
        $response = $repositoryForSpace.Environments.Create($environment)
        Write-Host "EnvironmentId: $($response.Id)"
    }
}