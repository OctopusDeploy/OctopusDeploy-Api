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
string[] environmentNames = { "Development", "Test" };
string stepName = "Run a script";

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

try
{
    // Get space
    var space = repository.Spaces.FindByName(spaceName);
    var repositoryForSpace = client.ForSpace(space);

    // Get environment ids
    List<string> environmentIds = new List<string>();
    foreach (var environmentName in environmentNames)
    {
        environmentIds.Add(repositoryForSpace.Environments.FindByName(environmentName).Id);
    }

    // Get project
    var project = repositoryForSpace.Projects.FindByName(projectName);

    // Get deployment process
    var deploymentProcess = repositoryForSpace.DeploymentProcesses.Get(project.DeploymentProcessId);

    // Get the step
    var step = deploymentProcess.Steps.Where(s => s.Name == stepName).FirstOrDefault();

    // Update the action
    foreach (var action in step.Actions)
    {
        foreach (string environmentId in environmentIds)
        {
            action.Environments.Add(environmentId);
        }
    }

    // Update the deployment process
    repositoryForSpace.DeploymentProcesses.Modify(deploymentProcess);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}