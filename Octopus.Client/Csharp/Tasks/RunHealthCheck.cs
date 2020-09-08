// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-YOURAPIKEY";
var spaceName = "Default";
var description = "Health check started from C# script";
var timeoutAfterMinutes = 5;
var machineTimeoutAfterMinutes = 5;

var environmentName = "Development";
var machineNames = new List<string>() {"octopus01-listening" };

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

try
{
    // Get space
    var space = repository.Spaces.FindByName(spaceName);
    var repositoryForSpace = client.ForSpace(space);

    // Get EnvironmentId
    string environmentId = null;
    if (string.IsNullOrWhiteSpace(environmentName) == false)
    {
        environmentId = repositoryForSpace.Environments.FindByName(environmentName).Id;
    }

    // Get MachineIds
    string[] machineIds = null;
    if (machineNames.Any())
    {
        machineIds = repositoryForSpace.Machines.FindAll().Where(m => machineNames.Contains(m.Name)).Select(m => m.Id).ToArray();
    }
    repositoryForSpace.Tasks.ExecuteHealthCheck(description, timeoutAfterMinutes, machineTimeoutAfterMinutes, environmentId, machineIds);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}