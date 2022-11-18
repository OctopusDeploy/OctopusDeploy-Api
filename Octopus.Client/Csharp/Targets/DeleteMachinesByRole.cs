// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://your.octopus.app";
var octopusAPIKey = "API-YOURAPIKEY";
string spaceName = "default";
string role = "MyRole";

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

try
{
    // Get space
    var space = repository.Spaces.FindByName(spaceName);
    var repositoryForSpace = client.ForSpace(space);

    // Get machine list
    var machines = repositoryForSpace.Machines.FindAll().Where(r => r.Roles.Contains(role));

    // Loop through list
    foreach (var machine in machines)
    {
        // Delete machine
        repositoryForSpace.Machines.Delete(machine);
    }
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}