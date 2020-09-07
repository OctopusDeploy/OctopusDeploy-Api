// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-YOURAPIKEY";
string spaceName = "default";
string projectName = "MyProject";
string projectGroupName = "Default project group";
string lifecycleName = "Default lifecycle";

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

try
{
    // Get space
    var space = repository.Spaces.FindByName(spaceName);
    var repositoryForSpace = client.ForSpace(space);

    // Get project group
    var projectGroup = repositoryForSpace.ProjectGroups.FindByName(projectGroupName);

    // Get lifecycle
    var lifecycle = repositoryForSpace.Lifecycles.FindByName(lifecycleName);

    // Create project
    var project = repositoryForSpace.Projects.CreateOrModify(projectName, projectGroup, lifecycle);
    project.Save();
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}