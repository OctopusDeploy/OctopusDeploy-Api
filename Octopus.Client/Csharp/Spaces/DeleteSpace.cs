// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

var OctopusURL = "https://youroctourl";
var OctopusAPIKey = "API-YOURAPIKEY";

var endpoint = new OctopusServerEndpoint(OctopusURL, OctopusAPIKey);
var repository = new OctopusRepository(endpoint);

var spaceName = "New Space";

try
{
    Console.WriteLine($"Getting space '{spaceName}'.");
    var space = repository.Spaces.FindByName(spaceName);

    if (space == null)
    {
        Console.WriteLine($"Could not find space '{spaceName}'.");
        return;
    }

    Console.WriteLine("Stopping task queue.");
    space.TaskQueueStopped = true;

    repository.Spaces.Modify(space);

    Console.WriteLine("Deleting space");
    repository.Spaces.Delete(space);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}