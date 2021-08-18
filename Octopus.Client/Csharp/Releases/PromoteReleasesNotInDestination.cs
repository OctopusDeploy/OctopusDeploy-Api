#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;
using System.Linq;

var octopusURL = "https://YourURL";
var octopusAPIKey = "API-YourAPIKey";

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);
var spaceName = "Default";
var sourceEnvironmentName = "Production";
var destinationEnvironmentName = "Test";
string[] projectList = new string[] { "MyProject" };

var space = repository.Spaces.FindByName(spaceName);
var repositoryForSpace = client.ForSpace(space);

// Get the source environment
var sourceEnvironment = repositoryForSpace.Environments.FindByName(sourceEnvironmentName);

// Get the destination environment
var destinationEnvironment = repositoryForSpace.Environments.FindByName(destinationEnvironmentName);


// Loop through project names
foreach (string projectName in projectList)
{
    // Get the project
    var project = repositoryForSpace.Projects.FindByName(projectName);

    Console.WriteLine(string.Format("The project id for the project name {0} is {2}", project.Name, project.Id));
    Console.WriteLine(string.Format("I have all the Ids I need, I am going to find the most recent successful deployment to {0}", sourceEnvironment.Name));

    // Get a list of deployments to the environment
    var sourceTaskList = repositoryForSpace.Deployments.FindBy(new string[] { project.Id }, new string[] { sourceEnvironment.Id }, 0, null).Items.Where(d => repositoryForSpace.Tasks.Get(d.TaskId).State == TaskState.Success).ToArray();

    if (sourceTaskList.Length == 0)
    {
        Console.WriteLine(string.Format("Unable to find a successful deployment for project {0} to {1}", project.Name, sourceEnvironment.Name));
        continue;
    }

    // Grab the latest task
    var lastSourceDeploymentTask = sourceTaskList[0];

    Console.WriteLine(string.Format("The Id of the last deployment for project {0} to {1} is {2}", project.Name, sourceEnvironment.Name, lastSourceDeploymentTask.Id));
    Console.WriteLine(string.Format("The release Id for {0} is {1}", lastSourceDeploymentTask.Id, lastSourceDeploymentTask.ReleaseId));

    bool canPromote = false;

    Console.WriteLine(string.Format("I have all the Ids I need, I am going to find the most recent successful deployment to {0}", destinationEnvironment.Name));

    // Get task list for destination
    var destinationTaskList = repositoryForSpace.Deployments.FindBy(new string[] { project.Id }, new string[] { destinationEnvironment.Id }, 0, null).Items.Where(d => repositoryForSpace.Tasks.Get(d.TaskId).State == TaskState.Success).ToArray(); ;

    if (destinationTaskList.Length == 0)
    {
        Console.WriteLine(string.Format("The destination has no releases, promoting."));
        canPromote = true;
    }

    // Get the last deployment to destination
    var lastDestinationDeploymentTask = destinationTaskList[0];

    Console.WriteLine(string.Format("The deployment Id of the last deployment for {0} to {1} is {2}", project.Name, destinationEnvironment.Name, lastDestinationDeploymentTask.Id));
    Console.WriteLine(string.Format("The release Id of the last deployment to the destination is {0}", lastDestinationDeploymentTask.ReleaseId));

    if (lastSourceDeploymentTask.ReleaseId != lastDestinationDeploymentTask.ReleaseId)
    {
        Console.WriteLine(string.Format("The releases on the source and destination don't match, promoting"));
        canPromote = true;
    }
    else
    {
        Console.WriteLine("The releases match, not promoting");
    }

    if (!canPromote)
    {
        Console.WriteLine(string.Format("Nothing to promote for {0}", project.Name));
    }

    // Create new deployment object
    var deployment = new Octopus.Client.Model.DeploymentResource();
    deployment.EnvironmentId = destinationEnvironment.Id;
    deployment.ReleaseId = lastSourceDeploymentTask.ReleaseId;

    // Queue the deployment
    repositoryForSpace.Deployments.Create(deployment);
}