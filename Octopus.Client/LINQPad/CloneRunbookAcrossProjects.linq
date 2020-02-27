<Query Kind="Statements">
  <NuGetReference>Octopus.Client</NuGetReference>
  <Namespace>Octopus.Client</Namespace>
  <Namespace>Octopus.Client.Model</Namespace>
</Query>

// ** ** ** ** ** ** ** ** ** ** ** ** ** ** 
// Welcome to this script. It will allow you to clone a runbook between projects
//
// Please take time to read through the script before running. The script will create a new
// runbook in your destination project, and will copy the name, description and process from the runbook you wish to clone.
//
var apiKey = "API-YOUR-KEY-HERE";
var server = "YOUR-SERVER-ADDRESS-HERE";
var spaceName = "SPACE-NAME";
var sourceProjectName = "SOURCE-PROJECT-NAME";
var sourceRunbookName = "SOURCE-RUNBOOK-NAME";
var destinationProjectName = "DESTINATION-PROJECT-NAME"
// ^^^^


var endpoint = new OctopusServerEndpoint(server, apiKey);
var rootRepo = new OctopusRepository(endpoint);

var space = rootRepo.Spaces.FindByName(spaceName);
Console.WriteLine($"Using Space named {space.Name} with id {space.Id}");

// Create space specific repository
var spaceRepo = rootRepo.ForSpace(space);

var sourceProject = spaceRepo.Projects.FindByName(sourceProjectName);

var runbookToClone = spaceRepo.Runbooks.FindByName(sourceProject, sourceRunbookName);
var runbookToCloneProcess = spaceRepo.RunbookProcesses.Get(runbookToClone.RunbookProcessId);

var destinationProject = spaceRepo.Projects.FindByName(destinationProjectName);

var newRunbookName = $"{runbookToClone.Name} - Clone";
var newRunbookDescription = $@"{runbookToClone.Description};

-------
Cloned from project {sourceProject.Name} with Id {sourceProject.Id}
";


var newRunbook = spaceRepo.Runbooks.Create(new RunbookResource()
{
	ProjectId = destinationProject.Id,
	Name = newRunbookName,
	Description = newRunbookDescription,
});


var newRunbookProcess = spaceRepo.RunbookProcesses.Get(newRunbook.RunbookProcessId);
foreach (var runbookStep in runbookToCloneProcess.Steps)
{
	runbookStep.Id = Guid.NewGuid().ToString();
	// WARNING:
	// You _need_ to be aware of what is in your steps, and if they reference entities 
	// - that do not exist (e.g. variables)
	// - or are not linked (e.g. tenants)
	// on the destination project
	newRunbookProcess.Steps.Add(runbookStep);
}
spaceRepo.RunbookProcesses.Modify(newRunbookProcess);


try
{
	var clonedRunbook = spaceRepo.Runbooks.FindByName(destinationProject, newRunbookName);
	Console.WriteLine($@"
Runbook '{runbookToClone.Name}' with id '{runbookToClone.Id}', from source project '{sourceProject.Name}' with id '{sourceProject.Id}'
has been successfully cloned to destination project '{destinationProject.Name}' with id '{destinationProject.Id}'
as Runbook '{clonedRunbook.Name}' with id '{clonedRunbook.Id}'
");
}
catch (Exception e)
{
	Console.WriteLine("Could not find cloned runbook");
	Console.WriteLine(e);	
}
