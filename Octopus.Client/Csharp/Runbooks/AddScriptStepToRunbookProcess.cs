// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-YOURAPIKEY";
var spaceName = "default";
var runbookName = "MyRunbook";
var stepName = "My new step";
var role = "target-role";
var scriptToRun = "Write-Host \"Hello World\" ";

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
    var processId = runbook.RunbookProcessId;

    var runbookProcess = repositoryForSpace.RunbookProcesses.Get(processId);

    // Check for existing step.
    if (runbookProcess.Steps.Any(s => s.Name == stepName))
    {
        Console.WriteLine("Existing step present with same name, please check and try again");
        return;
    }

    // Create PowerShell script step
    var step = new Octopus.Client.Model.DeploymentStepResource
    {
        Name = stepName,
        Condition = DeploymentStepCondition.Success,
        PackageRequirement = DeploymentStepPackageRequirement.LetOctopusDecide,
        StartTrigger = DeploymentStepStartTrigger.StartAfterPrevious
    };

    var stepAction = new DeploymentActionResource
    {
        ActionType = "Octopus.Script",
        Condition = DeploymentActionCondition.Success,
        Name = stepName
    };

    // Add step action properties
    stepAction.Properties.Add("Octopus.Actiom.RunOnServer", new Octopus.Client.Model.PropertyValueResource("false"));
    stepAction.Properties.Add("Octopus.Action.Script.ScriptSource", new Octopus.Client.Model.PropertyValueResource("Inline"));
    stepAction.Properties.Add("Octopus.Action.Script.ScriptBody", new Octopus.Client.Model.PropertyValueResource(scriptToRun));
    stepAction.Properties.Add("Octopus.Action.Script.Syntax", new Octopus.Client.Model.PropertyValueResource("PowerShell"));

    step.Properties.Add("Octopus.Action.TargetRoles", new Octopus.Client.Model.PropertyValueResource(role));

    // Add step to Actions
    step.Actions.Add(stepAction);

    // Add PowerShell script step to process
    runbookProcess.Steps.Add(step);

    // Update runbook process
    repositoryForSpace.RunbookProcesses.Modify(runbookProcess);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    Console.ReadLine();
    return;
}