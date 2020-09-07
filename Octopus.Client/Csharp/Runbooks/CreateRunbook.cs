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
string runbookName = "MyRunbook";

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

    // Create runbook retention object
    var runbookRetentionPolicy = new Octopus.Client.Model.RunbookRetentionPeriod();
    runbookRetentionPolicy.QuantityToKeep = 100;
    runbookRetentionPolicy.ShouldKeepForever = false;

    // Create runbook object
    var runbook = new Octopus.Client.Model.RunbookResource();
    runbook.Name = runbookName;
    runbook.ProjectId = project.Id;
    runbook.RunRetentionPolicy = runbookRetentionPolicy;

    // Save
    repositoryForSpace.Runbooks.Create(runbook);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    Console.ReadLine();
    return;
}