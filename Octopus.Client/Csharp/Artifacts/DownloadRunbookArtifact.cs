// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working variables
var octopusURL = "https://your.octopus.app";
var octopusAPIKey = "API-YOURAPIKEY";
string spaceName = "Default";
string projectName = "My Project";
string runbookName = "My Runbook";
string environmentName = "Development";
string fileDownloadPath = @"/path/to/download/artifact.txt";

// Note: Must include file extension in name.
string filenameForOctopus = "artifact_filename_in_octopus.txt";

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

try
{
    // Get space
    var space = repository.Spaces.FindByName(spaceName);
    var repositoryForSpace = client.ForSpace(space);

    // Get environment
    var environment = repositoryForSpace.Environments.FindByName(environmentName);

    // Get project
    var project = repositoryForSpace.Projects.FindOne(n => n.Name == projectName);

    // Get runbook
    var runbook = repositoryForSpace.Runbooks.FindByName(project, runbookName);

    var task = repositoryForSpace.Tasks.FindOne(t => t.State == Octopus.Client.Model.TaskState.Success, pathParameters: new { skip = 0, project = project.Id, runbook = runbook.Id, environment = environment.Id, includeSystem = false });
    if (task == null)
    {
        Console.WriteLine("No matching runbook task found!");
        return;
    }

    var artifact = repository.Artifacts.FindOne(t => t.Filename == filenameForOctopus, pathParameters: new { regarding = task.Id });

    if (artifact == null)
    {
        Console.WriteLine("No matching artifact found!");
        return;
    }

    Console.WriteLine("Getting artifact file content");
    var artifactStream = repositoryForSpace.Artifacts.GetContent(artifact);
    using (var fileStream = File.Create(fileDownloadPath))
    {
        artifactStream.Seek(0, SeekOrigin.Begin);
        artifactStream.CopyTo(fileStream);
    }
    Console.WriteLine("File content written to: {0}", fileDownloadPath);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}