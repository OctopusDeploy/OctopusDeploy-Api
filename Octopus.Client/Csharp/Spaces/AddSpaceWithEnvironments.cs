// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-YOURAPIKEY";

var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);

var spaceName = "New Space";
var description = "Space for the new, top secret project.";
var managersTeams = new string[] { };
var managersTeamMembers = new string[] { };

var environments = new string[] { "Development", "Test", "Production" };

var space = new SpaceResource
{
    Name = spaceName,
    Description = description,
    SpaceManagersTeams = new ReferenceCollection(managersTeams),
    SpaceManagersTeamMembers = new ReferenceCollection(managersTeamMembers),
    IsDefault = false,
    TaskQueueStopped = false
};

try
{
    Console.WriteLine($"Creating space '{spaceName}'.");
    space = repository.Spaces.Create(space);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}

var repositoryForSpace = repository.ForSpace(space);

foreach(var environmentName in environments)
{
    var environment = new EnvironmentResource {
        Name = environmentName
    };

    try
    {
        Console.WriteLine($"Creating environment '{environmentName}'.");
        repositoryForSpace.Environments.Create(environment);
    }
    catch (Exception ex)
    {
        Console.WriteLine(ex.Message);
        return;
    }
}