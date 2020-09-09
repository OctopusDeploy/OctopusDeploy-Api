// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-YOURAPIKEY";
string spaceName = "default";
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

    // Get teams
    var teams = repositoryForSpace.Teams.FindAll();

    // Get user role
    var userRole = repository.UserRoles.FindByName(userRoleName);

    // Loop through teams
    List<string> teamNames = new List<string>();
    foreach (var team in teams)
    {
        // Get scoped user roles
        var scopedUserRoles = repositoryForSpace.Teams.GetScopedUserRoles(team).Where(s => s.UserRoleId == userRole.Id);

        // Check for null
        if (scopedUserRoles != null && scopedUserRoles.Count() > 0)
        {
            // Add to teams
            teamNames.Add(team.Name);
        }
    }

    // Display which teams have use the role
    Console.WriteLine(string.Format("The following teams are using role {0}", userRoleName));
    foreach (string teamName in teamNames)
    {
        Console.WriteLine(teamName);
    }
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}