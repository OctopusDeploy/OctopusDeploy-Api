// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-YOURAPIKEY";
string spaceName = "default";
string hostName = "MyHost";
int tentaclePort = 10933;
string[] environmentNames = { "Development", "Production" };
string[] roles = { "MyRole" };
List<string> environmentIds = new List<string>();

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

    // Discover host
    var newTarget = repositoryForSpace.Machines.Discover(hostName, tentaclePort);

    // Fill in details for target
    foreach (string environmentId in environmentIds)
    {
        // Add to target
        newTarget.EnvironmentIds.Add(environmentId);
    }

    foreach (string role in roles)
    {
        newTarget.Roles.Add(role);
    }

    // Add machine to space
    repositoryForSpace.Machines.Create(newTarget);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}