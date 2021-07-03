// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-YOURAPIKEY";
string spaceName = "Default";
string environmentName = "Development";
string runbookName = "Runbook name";

// Leave blank if you'd like to use the published snapshot
string runbookSnapshotId = "";

Dictionary<string, string> promptedVariables = new Dictionary<string, string>();
// Enter multiple values using the .Add() method
// promptedVariables.Add("prompted-variable1", "variable1-value")

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

try
{
    // Get space
    var space = repository.Spaces.FindByName(spaceName);
    var repositoryForSpace = client.ForSpace(space);

    // Get runbook
    var runbook = repositoryForSpace.Runbooks.FindOne(n => n.Name == runbookName);

    // Get environment
    var environment = repositoryForSpace.Environments.FindByName(environmentName);

    // Use published snapshot if no id provided
    if (string.IsNullOrWhiteSpace(runbookSnapshotId))
    {
        runbookSnapshotId = runbook.PublishedRunbookSnapshotId;
    }

    var runbookTemplate = repositoryForSpace.Runbooks.GetRunbookRunTemplate(runbook);
    var deploymentPromotionTarget = runbookTemplate.PromoteTo.FirstOrDefault(p => p.Name == environmentName);
    var runbookPreview = repositoryForSpace.Runbooks.GetPreview(deploymentPromotionTarget);

    var formValues = new Dictionary<string, string>();
    
    // Associate variable vaelues for the runbook
    foreach (var variableName in promptedVariables.Keys)
    {
        var element = runbookPreview.Form.Elements.FirstOrDefault(e => (e.Control as Octopus.Client.Model.Forms.VariableValue).Name == variableName);
        if (element != null)
        {
            var runbookPromptedVariableId = element.Name;
            var runbookPromptedVariableValue = promptedVariables[variableName];
            formValues.Add(runbookPromptedVariableId, runbookPromptedVariableValue);
        }
    }

    // Create runbook run object
    Octopus.Client.Model.RunbookRunResource runbookRun = new RunbookRunResource();

    runbookRun.EnvironmentId = environment.Id;
    runbookRun.RunbookId = runbook.Id;
    runbookRun.ProjectId = runbook.ProjectId;
    runbookRun.RunbookSnapshotId = runbookSnapshotId;
    runbookRun.FormValues = formValues;
    // Execute runbook
    repositoryForSpace.RunbookRuns.Create(runbookRun);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}