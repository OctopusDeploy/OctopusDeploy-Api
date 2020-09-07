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
string[] environmentNames = { "Development", "Production" };

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

    // Get runbook
    var runbook = repositoryForSpace.Runbooks.FindMany(n => n.Name == runbookName && n.ProjectId == project.Id)[0];

    // Get environments
    foreach (var environmentName in environmentNames)
    {
        // Get environment
        var environment = repositoryForSpace.Environments.FindByName(environmentName);

        // Create runbook run object
        Octopus.Client.Model.RunbookRunResource runbookRun = new RunbookRunResource();
        runbookRun.EnvironmentId = environment.Id;
        runbookRun.RunbookId = runbook.Id;
        runbookRun.ProjectId = project.Id;
        runbookRun.RunbookSnapshotId = runbook.PublishedRunbookSnapshotId;

        // Execute runbook
        repositoryForSpace.RunbookRuns.Create(runbookRun);
    }
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}