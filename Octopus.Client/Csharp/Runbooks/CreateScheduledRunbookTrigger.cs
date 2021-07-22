// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://your.octopus.app";
var octopusAPIKey = "API-YOURAPIKEY";

// Define workig variables
string spaceName = "default";
string projectName = "MyProject";
string runbookName = "MyRunbook";

// Specify runbook trigger name
string runbookTriggerName = "RunbookTriggerName";

// Specify runbook trigger description
string runbookTriggerDescription = "RunbookTriggerDescription";

// Specify which environments the runbook should run in
List<string> runbookEnvironmentNames = new List<string>() { "Development" };

// What timezone do you want the trigger scheduled for
string runbookTriggerTimezone = "GMT Standard Time";

// Remove any days you don't want to run the trigger on
// Bitwise operator to add all days by default
Octopus.Client.Model.DaysOfWeek runbookTriggerDaysOfWeekToRun = DaysOfWeek.Monday | DaysOfWeek.Tuesday | DaysOfWeek.Wednesday | DaysOfWeek.Thursday | DaysOfWeek.Friday | DaysOfWeek.Saturday | DaysOfWeek.Sunday;

// Specify the start time to run the runbook each day in the format yyyy-MM-ddTHH:mm:ss.fffZ
// See https://docs.microsoft.com/en-us/dotnet/standard/base-types/custom-date-and-time-format-strings?view=netframework-4.8
string runbookTriggerStartTime = "2021-07-22T09:00:00.000Z";

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
    var runbook = repositoryForSpace.Runbooks.FindByName(project, runbookName);

    // Get environments for runbook trigger
    List<string> environmentIds = new List<string>();
    foreach (var environmentName in runbookEnvironmentNames)
    {
        var environment = repositoryForSpace.Environments.FindByName(environmentName);
        environmentIds.Add(environment.Id);
    }

    // Create scheduled trigger
    ProjectTriggerResource runbookScheduledTrigger = new ProjectTriggerResource
    {
        ProjectId = project.Id,
        Name = runbookTriggerName,
        Description = runbookTriggerDescription,
        IsDisabled = false,
        Filter = new OnceDailyScheduledTriggerFilterResource()
        {
            Timezone = runbookTriggerTimezone,
            StartTime = DateTime.Parse(runbookTriggerStartTime),
            DaysOfWeek = runbookTriggerDaysOfWeekToRun
        },
        Action = new Octopus.Client.Model.Triggers.RunRunbookActionResource
        {
            RunbookId = runbook.Id,
            EnvironmentIds = new ReferenceCollection(environmentIds)
        }
    };

    // Create runbook scheduled trigger
    var createdRunbookTrigger = repositoryForSpace.ProjectTriggers.Create(runbookScheduledTrigger);
    Console.WriteLine("Created runbook trigger: {0} ({1})", createdRunbookTrigger.Id, runbookTriggerName);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    Console.ReadLine();
    return;
}