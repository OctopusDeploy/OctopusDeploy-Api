// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-YOURAPIKEY";

string spaceName = "Default";
string feedName = "nuget.org";
string newFeedName = "nuget.org feed";

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

try
{
    // Get space
    var space = repository.Spaces.FindByName(spaceName);
    var repositoryForSpace = client.ForSpace(space);
    
    // Get Feed
    var feed = repositoryForSpace.Feeds.FindByName(feedName);
    
    // Change feed name
    feed.Name = newFeedName;
    
    // Update feed
    repositoryForSpace.Feeds.Modify(feed);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}