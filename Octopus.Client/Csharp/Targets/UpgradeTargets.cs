// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-YOURAPIKEY";
var spaceName = "default";
string[] machineNames = new string[] { "OctoTempTentacle" };

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

try
{
    // Get space
    var space = repository.Spaces.FindByName(spaceName);
    var repositoryForSpace = client.ForSpace(space);

    // Get machines
    List<string> machines = new List<string>();
    foreach (string machineName in machineNames)
    {
        // Get machine
        var machine = repositoryForSpace.Machines.FindByName(machineName);

        // Add to list
        machines.Add(machine.Id);
    }

    // Create task resource
    Octopus.Client.Model.TaskResource task = new TaskResource();
    task.Name = "Upgrade";
    task.Description = "Upgrade machines";
    task.Arguments.Add("MachineIds", machines);

    // Execute
    repositoryForSpace.Tasks.Create(task);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}