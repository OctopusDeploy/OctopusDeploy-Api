// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-YOURAPIKEY";
var spaceName = "default";
string projectName = "MyProject";
string teamName = "MyTeam";

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

    // Get team
    var team = repositoryForSpace.Teams.FindByName(teamName);

    // Get scoped user roles
    var scopedUserRoles = repository.Teams.GetScopedUserRoles(team);

    // Loop through scoped user roles and remove project reference
    foreach (var scopedUserRole in scopedUserRoles)
    {
        scopedUserRole.ProjectIds = new Octopus.Client.Model.ReferenceCollection(scopedUserRole.ProjectIds.Where(p => p != project.Id).ToArray());
        repositoryForSpace.ScopedUserRoles.Modify(scopedUserRole);
    }
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}