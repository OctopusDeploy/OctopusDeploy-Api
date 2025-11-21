// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using System;
using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "http://OctoTemp";
var octopusAPIKey = "API-YOURAPIKEY";
string projectName = "MyProject";
string spaceName = "default";

string processTemplateUsageStepName = "Run a Process Template";
string processTemplateSlug = "my-process-template";
string processTemplateVersionMask = "1.X";

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
    newStep.Name = processTemplateUsageStepName;
    newStep.Condition = DeploymentStepCondition.Success;

    // Create new script action
    Octopus.Client.Model.DeploymentActionResource stepAction = new DeploymentActionResource();
    stepAction.ActionType = "Octopus.ProcessTemplate";
    stepAction.Name = processTemplateUsageStepName;
    
    // Add process template specific properties into action properties
    stepAction.Properties.Add("Octopus.Action.ProcessTemplate.Reference.Slug", processTemplateSlug);
    stepAction.Properties.Add("Octopus.Action.ProcessTemplate.Reference.VersionMask", processTemplateVersionMask);
    
    // Add values for any required process template parameters into action properties
    stepAction.Properties.Add("LinuxWorker", "my-linux-worker");
    
    // Package parameter
    var packageReference = new PackageReference
    {
        Name = "Package Parameter",
        PackageId = "MyPackage",
    };
    packageReference.Properties.Add("PackageParameterName", "Package Parameter");
    packageReference.Properties.Add("SelectionMode", "deferred");
	
    stepAction.Packages.Add(packageReference);

    stepAction.Properties.Add("Package Parameter", "{\"PackageId\":\"MyPackage\",\"FeedId\":\"feeds-builtin\"}");

    // Sensitive parameter
    stepAction.Properties.Add("Sensitive Parameter", new PropertyValueResource(sensitiveValue, true));
    
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