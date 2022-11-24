// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://your.octopus.app";
var octopusAPIKey = "API-YOURAPIKEY";

string spaceName = "Default";
string feedName = "Octopus Server (built-in)";
string packageId = "Your-PackageId";

octopusURL = octopusURL.TrimEnd('/');

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
    
    // Get Packages
    var results = client.List<PackageResource>(feed.Links["SearchPackageVersionsTemplate"], new { packageId = packageId });

    // Print results
    foreach (var result in results.Items)
    {
        Console.WriteLine("Package: {0} with version: {1}", result.PackageId, result.Version);
    }
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}