// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-YOURAPIKEY";

string spaceName = "Default";
string packageName = "packagename";
string packageVersion = "1.0.0.0";
string outputFolder = @"C:\Temp\";

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

    // Get package details
    var packageDetails = repositoryForSpace.BuiltInPackageRepository.GetPackage(packageName, packageVersion);

    // Download package
    var webClient = new System.Net.WebClient();
    webClient.Headers["X-Octopus-ApiKey"] = octopusAPIKey;
    var uri = new Uri(octopusURL + "/" + packageDetails.Links["Raw"]);
    var filePath = Path.Combine(outputFolder, string.Format("{0}.{1}{2}", packageName, packageVersion, packageDetails.FileExtension));
    
    webClient.DownloadFile(uri, filePath);
    Console.WriteLine("Downloaded file to {0}", filePath);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}