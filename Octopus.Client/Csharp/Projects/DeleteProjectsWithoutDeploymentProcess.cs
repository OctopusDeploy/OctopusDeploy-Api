// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-YOURAPIKEY";
var spaceName = "default";

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
    var projects = repositoryForSpace.Projects.GetAll();

    // Loop through project
    foreach (var project in projects)
    {
        // Get deployment process
        var deploymentProcess = repositoryForSpace.DeploymentProcesses.Get(project.DeploymentProcessId);

        // Check for empty process
        if ((deploymentProcess.Steps == null) || (deploymentProcess.Steps.Count == 0))
        {
            // Delete project
            repositoryForSpace.Projects.Delete(project);
        }
    }
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}