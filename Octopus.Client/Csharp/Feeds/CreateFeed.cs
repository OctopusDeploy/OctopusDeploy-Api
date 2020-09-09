// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-YOURAPIKEY";

string spaceName = "Default";
string feedName = "nuget.org 3";
string feedURI = "https://api.nuget.org/v3/index.json";
int downloadAttempts = 5;
int downloadRetryBackoffSeconds = 10;
bool useExtendedApi = false;
// optional
string feedUsername = "";
string feedPassword = "";

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

try
{
    // Get space
    var space = repository.Spaces.FindByName(spaceName);
    var repositoryForSpace = client.ForSpace(space);

    var feedResource = new NuGetFeedResource
    {
        SpaceId = space.Id,
        Name = feedName,
        FeedUri = feedURI,
        DownloadAttempts = downloadAttempts,
        DownloadRetryBackoffSeconds = downloadRetryBackoffSeconds,
        EnhancedMode = useExtendedApi
    };
    if (!string.IsNullOrWhiteSpace(feedUsername))
    {
        feedResource.Username=feedUsername;
    }
    if (!string.IsNullOrWhiteSpace(feedPassword))
    {
        feedResource.Password = feedPassword;
    }
    var feed = repositoryForSpace.Feeds.Create(feedResource);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}