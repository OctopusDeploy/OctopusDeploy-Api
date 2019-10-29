
$path = Join-Path (Get-Item ((Get-Package Octopus.Client).source)).Directory.FullName "lib/net45/Octopus.Client.dll"
Add-Type -Path $path

# Define working variables
$octopusBaseURL = "https://youroctourl/api"
$octopusAPIKey = "API-YOURAPIKEY"
$endpoint = New-Object Octopus.Client.OctopusServerEndpoint($octopusBaseURL, $octopusAPIKey)
$repository = New-Object Octopus.Client.OctopusRepository($endpoint)

$roleName = "Project Deployer"
$spaceName = ""

try
{
    $space = $repository.Spaces.FindByName($spaceName)

    # Get specific role
    $role = $repository.UserRoles.FindByName($roleName)

    # Get all the teams
    $teams = $repository.Teams.GetAll()

    # Loop through the teams
    foreach ($team in $teams)
    {
        # Get all associated user roles
        $scopedUserRoles = $repository.Teams.GetScopedUserRoles($team)

        # Check to see if there was a space defined
        if (![string]::IsNullOrEmpty($spaceName))
        {
            # Filter on space
            $scopedUserRoles = $scopedUserRoles | Where-Object {$_.SpaceId -eq $space.Id}
        }

        # Loop through the scoped user roles
        foreach ($scopedUserRole in $scopedUserRoles)
        {
            # Check role id
            if ($scopedUserRole.UserRoleId -eq $role.Id)
            {
                # Display the team name
                Write-Output "Team: $($team.Name)"

                # Display the space name
                Write-Output "Space: $($repository.Spaces.Get($scopedUserRole.SpaceId).Name)"

                Write-Output "Users:"

                # Loop through the members
                foreach ($member in $team.MemberUserIds)
                {
                    # Get the user account
                    $user = $repository.Users.GetAll() | Where-Object {$_.Id -eq $member}
                    
                    # Display
                    Write-Output "$($user.DisplayName)"
                }

                # Check to see if there were external groups
                if (($null -ne $team.ExternalSecurityGroups) -and ($team.ExternalSecurityGroups.Count -gt 0))
                {
                    Write-Output "External security groups:"

                    # Loop through groups
                    foreach ($group in $team.ExternalSecurityGroups)
                    {
                        # Display group
                        Write-Output "$($group.Id)"
                    }
                }
            }
        }
    }
}
catch
{
    Write-Output "An error occurred: $($_.Exception.Message)"
}