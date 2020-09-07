// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-YOURAPIKEY";
string spaceName = "default";
string hostName = "OctoTempTentacle";
string[] environmentNames = { "Development", "Production" };
string[] roles = { "MyRole" };
List<string> environmentIds = new List<string>();
string tentacleThumbprint = "TentacleThumbprint";
string tentacleIdentifier = "PollingTentacleIdentifer"; // Must match value in Tentacle.config file on tentacle machine; ie poll://RandomCharacters

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

try
{
    // Get space
    var space = repository.Spaces.FindByName(spaceName);
    var repositoryForSpace = client.ForSpace(space);

    // Get environments
    foreach (var environmentName in environmentNames)
    {
        environmentIds.Add(repositoryForSpace.Environments.FindByName(environmentName).Id);
    }

    // Create new polling tentacle resource
    var newTarget = new Octopus.Client.Model.Endpoints.PollingTentacleEndpointResource();
    newTarget.Uri = string.Format("poll://{0}", tentacleIdentifier);
    newTarget.Thumbprint = tentacleThumbprint;

    // Create new machine resource
    var tentacle = new Octopus.Client.Model.MachineResource();
    tentacle.Endpoint = newTarget;
    tentacle.Name = hostName;

    // Fill in details for target
    foreach (string environmentId in environmentIds)
    {
        // Add to target
        tentacle.EnvironmentIds.Add(environmentId);
    }

    foreach (string role in roles)
    {
        tentacle.Roles.Add(role);
    }

    // Add machine to space
    repositoryForSpace.Machines.Create(tentacle);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}