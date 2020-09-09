// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-YOURAPIKEY";
string spaceName = "default";
string[] environmentNames = { "Development", "Production" };
string teamName = "MyTeam";
string userRoleName = "Deployment creator";

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

try
{
    // Get space
    var space = repository.Spaces.FindByName(spaceName);
    var repositoryForSpace = client.ForSpace(space);

    // Get team
    var team = repositoryForSpace.Teams.FindByName(teamName);

    // Get user role
    var userRole = repository.UserRoles.FindByName(userRoleName);

    // Get scoped user role
    var scopedUserRole = repository.Teams.GetScopedUserRoles(team).FirstOrDefault(s => s.UserRoleId == userRole.Id);

    // Get environment ids
    foreach (var environmentName in environmentNames)
    {
        scopedUserRole.EnvironmentIds.Add(repositoryForSpace.Environments.FindByName(environmentName).Id);
    }

    // Update scoped user role
    repositoryForSpace.ScopedUserRoles.Modify(scopedUserRole);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}