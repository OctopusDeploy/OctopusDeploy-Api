// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-YOURAPIKEY";
string apiKeyPurpose = "Key used with C# application";

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);

try
{
    // Get Current user
    var user = repository.Users.GetCurrent();

    // Create API Key for user
    var apiKeyResponse = repository.Users.CreateApiKey(user, apiKeyPurpose);

    // Return the API Key
    Console.WriteLine("API Key created: {0}", apiKeyResponse.ApiKey);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}