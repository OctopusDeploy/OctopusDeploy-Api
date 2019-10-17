# Define working variables
$OctopusServerUrl = "https://YourServerUrl"
$ApiKey = "API-YourAPIKey"
$RoleName = "RoleToLookFor"

# Get reference to role
$role = (Invoke-RestMethod -Method Get -Uri "$OctopusServerUrl/api/userroles/all" -Headers @{"X-Octopus-ApiKey"="$ApiKey"}) | Where-Object {$_.Name -eq $RoleName}

# Get list of teams
$teams = (Invoke-RestMethod -Method Get -Uri ("$OctopusServerUrl/api/teams/all") -Headers @{"X-Octopus-ApiKey"="$ApiKey"})

# Loop through teams
foreach ($team in $teams)
{
    # Check for scoped user roles
    $scopedUserRoleLinks = $scopedUserRoleLinks = $team.Links | Where-Object -Property "ScopedUserRoles"

    # Loop through the links
    foreach ($scopedUserRoleLink in $scopedUserRoleLinks)
    {
        # Get the scoped user role
        $scopedUserRole = Invoke-RestMethod -Method Get -Uri ("$OctopusServerUrl$($scopedUserRoleLink.Self)/scopeduserroles") -Headers @{"X-Octopus-ApiKey"="$ApiKey"}

        # Check to see if the team has the role
        if ($null -ne ($scopedUserRole.Items | Where-Object {$_.UserRoleId -eq $role.Id}))
        {
            # Display team name
            Write-Output "Team: $($team.Name)"

            # Loop through members
            foreach ($userId in $team.MemberUserIds)
            {
                # Get user object
                $user = Invoke-RestMethod -Method Get -Uri ("$OctopusServerUrl/api/users/$userId") -Headers @{"X-Octopus-ApiKey"="$ApiKey"}
                
                # Display user
                Write-Output "$($user.DisplayName)"
            }

            # External groups
            Write-Output "External security groups: $($team.ExternalSecurityGroups.Id)"
        }
    }

}

