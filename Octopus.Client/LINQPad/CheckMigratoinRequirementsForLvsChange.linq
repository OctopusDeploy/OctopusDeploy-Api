<Query Kind="Program">
  <NuGetReference>Octopus.Client</NuGetReference>
  <Namespace>Octopus.Client</Namespace>
  <Namespace>Octopus.Client.Model</Namespace>
</Query>

void Main()
{
	// ** ** ** ** ** ** ** ** ** ** ** ** ** ** 
	// Welcome to this script. It will allow you to get an idea of the state of your LVS permissions.
	// **
	// For more info see here: https://g.octopushq.com/LibraryVariableSetAccessMigration
	// **
	// If you would like to discuss the implications of this change to your Octopus server please contact support@octopus.com
	// To run this script please populate the `apiKey` value from user with sufficient access to all your Spaces, and your server url
	var apiKey = "API-YOUR-KEY-HERE";
	var serverAddress = "YOUR-SERVER-ADDRESS-HERE";
	// ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
	
	var octopusServer = new Octopus.Client.OctopusServerEndpoint(serverAddress, apiKey);
	var repo = new Octopus.Client.OctopusRepository(octopusServer);

	var nl = Environment.NewLine;
	var allUserRoles = repo.UserRoles.FindAll().ToList();

	$"Checking {allUserRoles.Count()} users roles. This check cannot be conclusive because roles are often combined with others to form the final set of user permissions{nl}".Dump();
	var possiblyProblematicUserRoles = allUserRoles
		.Where(ur => 
			ur.GrantedSpacePermissions.Contains(Permission.LibraryVariableSetView)
				&& !ur.GrantedSpacePermissions.Contains(Permission.EnvironmentView));
				
	if (possiblyProblematicUserRoles.Any())
	{
		var roles = string.Join(nl, possiblyProblematicUserRoles.Select(Details));
		($"The following UserRoles: {nl}{roles}{nl}have `LibraryVariableSetView` but not `EnvironmentView`.{nl}"
		+ $"If used in isolation would allow users to have configured permissions that would require migration.{nl}{nl}"
		+ $"Prior to Octopus 2019.11 these permissions needed to work together.{nl}"
		+ $"As part of upgrading to 2019.11 users who gain their access via this UserRole{nl}"
		+ $"and no other UserRole that grants them EnvironmentView will require migration.{nl}"
		+ $"Please review the users who currently only have LibraryVariableSetView (and LibraryVariableSetEdit) but lack EnvironmentView{nl}"
		+ $"because their access to Library Variable Sets is currently flawed.{nl}{nl}").Dump();
	}

	var allUsers = repo.Users.FindAll().ToList();
	var allSpaces = repo.Spaces.FindAll().ToList();

	$"Checking {allUsers.Count()} users across {allSpaces.Count()} spaces now...".Dump();
	"------------------------------".Dump();
	var clearSpaceQty = 0;
	foreach(var s in allSpaces)
	{
		$"Checking the '{s.Name}' space".Dump();
		if(CheckUsersInThisSpace(s))
		{
			clearSpaceQty++;
			$"		GREAT => no users requiring a migration".Dump();
		}

		if (clearSpaceQty == allSpaces.Count())
		{
			"*******************************".Dump();
			$"Good news it is unlikely this coming migration will need to make changes on your Octopus server.".Dump();

			"*******************************".Dump();
		}
		
		"------------------------------".Dump();
	}

	bool CheckUsersInThisSpace(SpaceResource space)
	{
		var thisSpaceRepo = repo.ForSpace(space);
		var allClear = true;
		foreach (var userToCheck in allUsers)
		{
			var thisUsersPermissionsForThisSpace = thisSpaceRepo.UserPermissions.GetConfiguration(userToCheck);
			thisUsersPermissionsForThisSpace.SpacePermissions.TryGetValue(Permission.LibraryVariableSetView, out var lvsView);
			thisUsersPermissionsForThisSpace.SpacePermissions.TryGetValue(Permission.LibraryVariableSetEdit, out var lvsEdit);
			thisUsersPermissionsForThisSpace.SpacePermissions.TryGetValue(Permission.EnvironmentView, out var envView);

			if (lvsView != null)
			{
				if (envView == null)
				{
					// This is the least ideal case.
					// If there are users who have LibraryVariableSetView/LibraryVariableSetEdit but NOT EnvironmentView
					// They require migrations to ensure they are taken out of roles/teams which currently grant LibraryVariableSetView/LibraryVariableSetEdit
					// As post migration it's not longer coupled to EnvironmentView
					allClear = false;
					var hasLvsEdit = lvsEdit == null ? "" : " and LibraryVariableSetEdit";
					($"User {Details(userToCheck)} currently has LibraryVariableSetView{hasLvsEdit} but does not have EnvironmentView. {nl}"
					+ "You should review this users access, as currently LibraryVariableSetView and LibraryVariableSetEdit do not work for this user.")
					.Dump();
				}
				else
				{
					// We cannot test this exhaustively via the API on an instance of Octopus prior to an upgrade to 2019.11
					// all we can check and report on here is a the chance it may be a problem
					var hasUnscopedEnvironmentView = envView.Any(v => v.RestrictedToEnvironmentIds.Count == 0);

					if (!hasUnscopedEnvironmentView)
					{
						allClear = false;
						($"{Details(userToCheck)} may require a minor migration").Dump();
					}
				}
			}
		}
		return allClear;
	}
}


string Details(UserResource u) => $"User '{u.Username}' with id: {u.Id}";
string Details(UserRoleResource u) => $"	> '{u.Name}' ({u.Id})";