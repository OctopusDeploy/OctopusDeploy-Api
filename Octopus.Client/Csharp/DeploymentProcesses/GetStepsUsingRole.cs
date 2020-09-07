// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-YOURAPIKEY";
string spaceName = "default";
string roleName = "My role";

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
    var projectList = repositoryForSpace.Projects.GetAll();

    // Loop through list
    foreach (var project in projectList)
    {
        // Get the deployment process
        var deploymentProcess = repositoryForSpace.DeploymentProcesses.Get(project.DeploymentProcessId);

        // Loop through steps
        foreach (var step in deploymentProcess.Steps)
        {
            // Get property value
            PropertyValueResource propertyValue = null;
            if (step.Properties.TryGetValue("Octopus.Action.TargetRoles", out propertyValue))
            {
                if ((propertyValue != null) && (propertyValue.Value.ToString().ToLower().Split(',').Contains(roleName.ToLower())))
                {
                    Console.WriteLine(string.Format("Step [{0}] from project [{1}] is using the role [{2}]", step.Name, project.Name, roleName));
                }
            }
        }
    }
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}