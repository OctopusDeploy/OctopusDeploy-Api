// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;


// Declare working varibles
var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-APIKEY";
var spaceName = "default";
string packageFile = "path\\to\\file";
System.IO.FileStream fileStream = null;

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

try
{
    // Get space
    var space = repository.Spaces.FindByName(spaceName);
    var repositoryForSpace = client.ForSpace(space);

    // Open file stream
    fileStream = new System.IO.FileStream(packageFile, System.IO.FileMode.Open);

    // Push package
    repositoryForSpace.BuiltInPackageRepository.PushPackage(packageFile, fileStream);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    Console.ReadLine();
    return;
}
finally
{
    if (fileStream != null)
    {
        fileStream.Close();
    }
}