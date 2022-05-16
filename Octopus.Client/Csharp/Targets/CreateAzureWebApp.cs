// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "http://octotemp";
var octopusAPIKey = "API-KEY";
string spaceName = "default";
string[] environmentNames = { "Development", "Production" };
string[] roles = { "MyRole" };
List<string> environmentIds = new List<string>();
string azureServicePrincipalName = "MyAzureAccount";
string azureResourceGroupName = "Target-Hybrid-rg";
string azureWebAppName = "s-OctoPetShop-Web";

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

try
{
    // Get space
    var space = repository.Spaces.FindByName(spaceName);
    var repositoryForSpace = client.ForSpace(space);

    // Get environments
    foreach (var environmentName in environmentNames)
    {
        environmentIds.Add(repositoryForSpace.Environments.FindByName(environmentName).Id);
    }

    // Get Azure account
    var azureAccount = repositoryForSpace.Accounts.FindByName(azureServicePrincipalName);

    // Create new azure web app object
    var azureWebAppTarget = new Octopus.Client.Model.Endpoints.AzureWebAppEndpointResource();
    azureWebAppTarget.AccountId = azureAccount.Id;
    azureWebAppTarget.ResourceGroupName = azureResourceGroupName;
    azureWebAppTarget.WebAppName = azureWebAppName;

    // Create new machine resource
    var tentacle = new Octopus.Client.Model.MachineResource();
    tentacle.Endpoint = azureWebAppTarget;
    tentacle.Name = azureWebAppName;

    // Fill in details for target
    foreach (string environmentId in environmentIds)
    {
        // Add to target
        tentacle.EnvironmentIds.Add(environmentId);
    }

    foreach (string role in roles)
    {
        tentacle.Roles.Add(role);
    }

    // Add machine to space
    repositoryForSpace.Machines.Create(tentacle);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}