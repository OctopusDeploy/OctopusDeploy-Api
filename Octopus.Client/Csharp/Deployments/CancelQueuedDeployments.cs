// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "http://octotemp";
var octopusAPIKey = "API-KEY";
string spaceName = "default";

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

try
{
    // Get space
    var space = repository.Spaces.FindByName(spaceName);
    var repositoryForSpace = client.ForSpace(space);

    // Get queued deployemnts
    var queuedDeployments = repositoryForSpace.Tasks.FindAll().Where(d => d.State == TaskState.Queued && !d.HasBeenPickedUpByProcessor && d.Name == "Deploy");

    // Loop through results
    foreach (var task in queuedDeployments)
    {
        // Cancel deployment
        repositoryForSpace.Tasks.Cancel(task);
    }
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}