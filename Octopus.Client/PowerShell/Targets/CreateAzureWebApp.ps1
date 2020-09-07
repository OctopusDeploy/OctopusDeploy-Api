# Load octopus.client assembly
Add-Type -Path "path\to\Octopus.Client.dll"

# Octopus variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$azureServicePrincipalName = "MyAzureAccount"
$azureResourceGroupName = "MyResourceGroup"
$azureWebAppName = "MyAzureWebApp"
$spaceName = "default"
$environmentNames = @("Development", "Production")
$roles = @("MyRole")


$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURL, $octopusAPIKey
$repository = New-Object Octopus.Client.OctopusRepository $endpoint
$client = New-Object Octopus.Client.OctopusClient $endpoint

try
{
    # Get space
    $space = $repository.Spaces.FindByName($spaceName)
    $repositoryForSpace = $client.ForSpace($space)

    # Get environment ids
    $environments = $repositoryForSpace.Environments.FindAll() | Where-Object {$environmentNames -contains $_.Name}

    # Get Azure account
    $azureAccount = $repositoryForSpace.Accounts.FindByName($azureServicePrincipalName)

    # Create new Azure Web App object
    $azureWebAppTarget = New-Object Octopus.Client.Model.Endpoints.AzureWebAppEndpointResource
    $azureWebAppTarget.AccountId = $azureAccount.Id
    $azureWebAppTarget.ResourceGroupName = $azureResourceGroupName
    $azureWebAppTarget.WebAppName = $azureWebAppName

    # Create new machine object
    $machine = New-Object Octopus.Client.Model.MachineResource
    $machine.Endpoint = $azureWebAppTarget
    $machine.Name = $azureWebAppName
    
    # Add Environments
    foreach ($environment in $environments)
    {
        # Add to target
        $machine.EnvironmentIds.Add($environment.Id)
    }

    # Add roles
    foreach ($role in $roles)
    {
        $machine.Roles.Add($role)
    }
        
    # Add to machine to space
    $repositoryForSpace.Machines.Create($machine)
}
catch
{
    Write-Host $_.Exception.Message
}