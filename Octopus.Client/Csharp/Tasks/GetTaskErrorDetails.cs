// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://your.octopus.app";
var octopusAPIKey = "API-AKEY";
string spaceName = "Default";
string projectName = "Your Project Name";
string releaseVersion = "0.0.1";

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

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
    // Get release
    var release = repositoryForSpace.Projects.GetReleaseByVersion(project, releaseVersion);

    // Get 100 deployments of that release
    var deployments = repositoryForSpace.Releases.GetDeployments(release, 0, 100);

    // Get last deployment
    var lastDeployment = deployments.Items.FirstOrDefault();
    if (lastDeployment == null)
    {
        throw new NullReferenceException("Couldnt find deployments of release:" + releaseVersion);
    }

    // Get deployment task 
    var task = repositoryForSpace.Tasks.Get(lastDeployment.TaskId);
    // Get task details
    var details = repository.Tasks.GetDetails(task);

    // Get fatal and Error logs
    List<ActivityLogElement> activityErrorLogs = new List<Octopus.Client.Model.ActivityLogElement>();
    foreach (var log in details.ActivityLogs)
    {
        var errorLogs = FindErrorLogs(log);
        activityErrorLogs.AddRange(errorLogs);
    }
    
    // Display logs found
    foreach (var log in activityErrorLogs)
    {
        Console.WriteLine("{0}: {1}", log.Category, log.MessageText);
    }
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}


// Function to recursively find error logs from a task detail's Activity Element
List<ActivityLogElement> FindErrorLogs(ActivityElement log)
{
	List<ActivityLogElement> activityLogs = new List<Octopus.Client.Model.ActivityLogElement>();
	// Find errors in Log elements first
	if (log.LogElements != null && log.LogElements.Any())
	{
		var fatalLogs = log.LogElements.Where(l => l.Category == "Fatal").ToList();
		activityLogs.AddRange(fatalLogs);

		var errorLogs = log.LogElements.Where(l => l.Category == "Error").ToList();
		activityLogs.AddRange(errorLogs);
	}

	// Recursively check child logs
	if (log.Children != null && log.Children.Any())
	{
		foreach (var child in log.Children)
		{
			var childActivityLogs = FindErrorLogs(child);
			activityLogs.AddRange(childActivityLogs);
		}
	}
	return activityLogs;
}