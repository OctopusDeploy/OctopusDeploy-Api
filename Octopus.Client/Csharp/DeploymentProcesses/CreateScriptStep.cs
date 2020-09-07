// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "http://OctoTemp";
var octopusAPIKey = "API-YOURAPIKEY";
string stepName = "Run a script";
string roleName = "My role";
string scriptBody = "Write-Host \"Hello world\"";
string projectName = "MyProject";
string spaceName = "default";

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

    // Get the deployment process
    var deploymentProcess = repositoryForSpace.DeploymentProcesses.Get(project.DeploymentProcessId);

    // Create new step object
    Octopus.Client.Model.DeploymentStepResource newStep = new DeploymentStepResource();
    newStep.Name = stepName;
    newStep.Condition = DeploymentStepCondition.Success;
    newStep.Properties.Add("Octopus.Action.TargetRoles", roleName);

    // Create new script action
    Octopus.Client.Model.DeploymentActionResource stepAction = new DeploymentActionResource();
    stepAction.ActionType = "Octopus.Script";
    stepAction.Name = stepName;
    stepAction.Properties.Add("Octopus.Action.Script.ScriptBody", scriptBody);

    // Add step action and step to process
    newStep.Actions.Add(stepAction);
    deploymentProcess.Steps.Add(newStep);

    // Update process
    repositoryForSpace.DeploymentProcesses.Modify(deploymentProcess);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}