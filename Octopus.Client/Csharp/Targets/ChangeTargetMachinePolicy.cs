// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-YOURAPIKEY";
string spaceName = "default";
string machineName = "MyMachine";
string machinePolicyName = "TestPolicy";

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

try
{
    // Get space
    var space = repository.Spaces.FindByName(spaceName);
    var repositoryForSpace = client.ForSpace(space);

    // Get machine list
    var machine = repositoryForSpace.Machines.FindByName(machineName);

    // Get machine policy
    var machinePolicy = repositoryForSpace.MachinePolicies.FindByName(machinePolicyName);

    // Change machine policy for machine
    machine.MachinePolicyId = machinePolicy.Id;
    repositoryForSpace.Machines.Modify(machine);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}