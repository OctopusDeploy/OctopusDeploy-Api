var octopusBaseURL = "https://youroctourl/api";
var octopusAPIKey = "API-YOURAPIKEY";

var endpoint = new OctopusServerEndpoint(octopusBaseURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);

string roleName = "Project Deployer";
var spaceName = "";

try
{
    // Get space id
    var space = repository.Spaces.FindByName(spaceName);

    // Get reference to the role
    var role = repository.UserRoles.FindByName(roleName);

    // Get all teams to search
    var teams = repository.Teams.FindAll();

    // Loop through the teams
    foreach (var team in teams)
    {
        // Retrieve scoped user roles
        var scopedUserRoles = repository.Teams.GetScopedUserRoles(team);

        // Check to see if there was a space name specified
        if (!string.IsNullOrEmpty(spaceName))
        {
            // filter returned scopedUserRoles
            scopedUserRoles = scopedUserRoles.Where(x => x.SpaceId == space.Id).ToList();
        }

        // Loop through returned roles
        foreach (var scopedUserRole in scopedUserRoles)
        {
            // Check to see if it's the role we're looking for
            if (scopedUserRole.UserRoleId == role.Id)
            {
                // Output team name
                Console.WriteLine(string.Format("Team: {0}", team.Name));

                // Output space name
                Console.WriteLine(string.Format("Space: {0}", repository.Spaces.Get(scopedUserRole.SpaceId).Name));

                Console.WriteLine("Users:")

                // Loop through team members
                foreach (var member in team.MemberUserIds)
                {
                    // Get the user object
                    var user = repository.Users.Get(member);

                    // Display the user name
                    Console.WriteLine(user.DisplayName);
                }

                // Check for external groups
                if ((team.ExternalSecurityGroups != null) && (team.ExternalSecurityGroups.Count > 0))
                {
                    //
                    Console.WriteLine("External security groups:");

                    // Iterate through external security groups
                    foreach (var group in team.ExternalSecurityGroups)
                    {
                        Console.WriteLine(group.Id);
                    }
                }
            }
        }
    }
}
catch (Exception ex)
{
    Console.Writeline(ex.Message);
}