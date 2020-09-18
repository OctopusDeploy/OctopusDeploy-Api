// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-APIKEY";
string spaceName = "default";
string projectName = "MyProject";
string runbookName = "MyRunbook";
string snapshotName = "Snapshot 7PNENH8";

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

	// Get runbook snapshot
	var runbookSnapshot = repositoryForSpace.RunbookSnapshots.FindOne(rs => rs.ProjectId == project.Id && rs.Name == snapshotName);

	// Publish the snapshot
	runbook.PublishedRunbookSnapshotId = runbookSnapshot.Id;
	repositoryForSpace.Runbooks.Modify(runbook);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}