// If using .net Core, be sure to add the NuGet package of System.Security.Permissions
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-YOURAPIKEY";
string spaceName = "default";
string librarySetName = "MyLibrarySet";

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

try
{
    // Get space
    var space = repository.Spaces.FindByName(spaceName);
    var repositoryForSpace = client.ForSpace(space);

    // Get projects
    var projects = repositoryForSpace.Projects.GetAll();

    // Get library set
    var librarySet = repositoryForSpace.LibraryVariableSets.FindByName(librarySetName);

    // Loop through projects
    Console.WriteLine(string.Format("The following projects are using {0}", librarySetName));
    foreach (var project in projects)
    {
        if (project.IncludedLibraryVariableSetIds.Contains(librarySet.Id))
        {
            Console.WriteLine(project.Name);
        }
    }
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}