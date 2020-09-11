// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-YOURAPIKEY";
var spaceName = "default";
string projectName = "MyProject";

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

try
{
    // Get space
    var space = repository.Spaces.FindByName(spaceName);
    var repositoryForSpace = client.ForSpace(space);

    // Get project
    var project = repositoryForSpace.Projects.FindByName(projectName);

    var projectTriggers = repositoryForSpace.Projects.GetAllTriggers(project);
    
    foreach (var projectTrigger in projectTriggers)
    {
        // Disable trigger
        projectTrigger.IsDisabled = true;
        repositoryForSpace.ProjectTriggers.Modify(projectTrigger);
    }
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}