// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-YOURAPIKEY";

string spaceName = "Default";

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

try
{
    // Get space
    var space = repository.Spaces.FindByName(spaceName);
    var repositoryForSpace = client.ForSpace(space);

    // Get All feeds
    var feeds = repositoryForSpace.Feeds.FindAll();

    foreach (var feed in feeds)
    {
        Console.WriteLine("Feed Id: {0}", feed.Id);
        Console.WriteLine("Feed Name: {0}", feed.Name);
        Console.WriteLine("Feed Type: {0}", feed.FeedType);
        Console.WriteLine();
    }
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}