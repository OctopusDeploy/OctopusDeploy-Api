var octopusServerUrl = "https://YourServerUrl";
var apiKey = "https://YourServerUrl";


var endpoint = new OctopusServerEndpoint(octopusServerUrl, apiKey);
var repository = new OctopusRepository(endpoint);

string roleName = "Project Deployer";
var spaceName = "";

var spaceId = repository.Spaces.FindByName(spaceName);

// Get reference to the role
var role = repository.UserRoles.FindByName(roleName);

// Get all teams to search
var teams = repository.Teams.FindAll();

// Check to see if a spaceid was specified
if (spaceId != null)
{
    // limit teams to the specific space
    teams = teams.Where(x => x.SpaceId == spaceId.Id).ToList();
}

// Loop through the teams
foreach (var team in teams)
{
    // Retrieve scoped user roles
    var scopedUserRoles = repository.Teams.GetScopedUserRoles(team);

    // Loop through returned roles
    foreach (var scopedUserRole in scopedUserRoles)
    {
        // Check to see if it's the role we're looking for
        if (scopedUserRole.UserRoleId == role.Id)
        {
            // Output team name
            Console.WriteLine(string.Format("Team: {0}", team.Name));

            // Loop through team members
            foreach (var member in team.MemberUserIds)
            {
                // Get the user object
                var user = repository.Users.Get(member);

                // Display the user name
                Console.WriteLine(user.DisplayName);
            }
        }
    }
}
