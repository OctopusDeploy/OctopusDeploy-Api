# Define working variables
$octopusBaseURL = "https://youroctourl/api"
$octopusAPIKey = "API-YOURAPIKEY"
$headers = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$roleName = "Project Deployer"
$spaceName = "" # Leave blank if you're using an older version of Octopus or you want to search all spaces

try
{
    # Get the space id
    $spaceId = ((Invoke-RestMethod -Method Get -Uri "$octopusBaseURL/spaces/all" -Headers $headers -ErrorVariable octoError) | Where-Object {$_.Name -eq $spaceName}).Id

    # Get reference to role
    $role = (Invoke-RestMethod -Method Get -Uri "$octopusBaseURL/userroles/all" -Headers $headers -ErrorVariable octoError) | Where-Object {$_.Name -eq $roleName}

    # Get list of teams
    $teams = (Invoke-RestMethod -Method Get -Uri "$octopusBaseURL/teams/all" -Headers $headers -ErrorVariable octoError)

    # Loop through teams
    foreach ($team in $teams)
    {
        # Get the scoped user role
        $scopedUserRoles = Invoke-RestMethod -Method Get -Uri ("$octopusBaseURL/teams/$($team.Id)/scopeduserroles") -Headers $headers -ErrorVariable octoError
        
        # Loop through the scoped user roles
        foreach ($scopedUserRole in $scopedUserRoles)
        {
            # Check to see if space was specified
            if (![string]::IsNullOrEmpty($spaceId))
            {
                # Filter items by space
                $scopedUserRole.Items = $scopedUserRole.Items | Where-Object {$_.SpaceId -eq $spaceId}
            }

            # Check to see if the team has the role
            if ($null -ne ($scopedUserRole.Items | Where-Object {$_.UserRoleId -eq $role.Id}))
            {
                # Display team name
                Write-Output "Team: $($team.Name)"

                # check space id
                if ([string]::IsNullOrEmpty($spaceName))
                {
                    # Get the space id
                    $teamSpaceId = ($scopedUserRole.Items | Where-Object {$_.UserRoleId -eq $role.Id}).SpaceId

                    # Get the space name
                    $teamSpaceName = (Invoke-RestMethod -Method Get -Uri "$octopusBaseURL/spaces/$teamSpaceId" -Headers $headers -ErrorVariable octoError).Name

                    # Display the space name
                    Write-Output "Space: $teamSpaceName"
                }
                else
                {
                    # Display the space name
                    Write-Output "Space: $spaceName"
                }

                Write-Output "Users:"

                # Loop through members
                foreach ($userId in $team.MemberUserIds)
                {
                    # Get user object
                    $user = Invoke-RestMethod -Method Get -Uri ("$octopusBaseURL/users/$userId") -Headers $headers -ErrorVariable octoError
                    
                    # Display user
                    Write-Output "$($user.DisplayName)"
                }

                # Check for external security groups
                if (($null -ne $team.ExternalSecurityGroups) -and ($team.ExternalSecurityGroups.Count -gt 0))
                {
                    # External groups
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
    if ([string]::IsNullOrEmpty($octoError))
    {
        Write-Output "There was an error during the request: $($octoError.Message)"
    }
    else
    {
        Write-Output "An error occurred: $($_.Exception.Message)"
    }
}
