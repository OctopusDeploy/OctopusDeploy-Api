// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;
using Octopus.Client.Model.Endpoints;

var octopusURL = "https://your.octopus.app";
var octopusAPIKey = "API-YOURAPIKEY";

var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);

var spaceName = "Default";

void WriteTentacleStatus(MachineBasedResource tentacle)
{
    var endpoint = tentacle.Endpoint as TentacleEndpointResource;
    if (endpoint == null) return;

    Console.WriteLine("Checking Tentacle version for {0}", tentacle.Name);
    Console.WriteLine("\tTentacle status:  {0}", tentacle.HealthStatus);
    Console.WriteLine("\tCurrent version: {0}", endpoint.TentacleVersionDetails.Version);
    Console.WriteLine("\tUpgrade suggested: {0}", endpoint.TentacleVersionDetails.UpgradeSuggested);
    Console.WriteLine("\tUpgrade required: {0}", endpoint.TentacleVersionDetails.UpgradeRequired);
}

try
{
    // Get the space to work in
    var space = repository.Spaces.FindByName(spaceName);
    Console.WriteLine($"Using Space named {space.Name} with id {space.Id}");

    // Create space specific repository
    var repositoryForSpace = repository.ForSpace(space);

    // Get Tentacles
    var targets = repositoryForSpace.Machines.FindAll();
    var workers = repositoryForSpace.Workers.FindAll();

    foreach (var target in targets)
    {
        WriteTentacleStatus(target);
    }

    foreach (var worker in workers)
    {
        WriteTentacleStatus(worker);
    }
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
}