
$path = Join-Path (Get-Item ((Get-Package Octopus.Client).source)).Directory.FullName "lib/net45/Octopus.Client.dll"
Add-Type -Path $path

# Define working variables
$server = "https://YourServerUrl"
$apiKey = "API-YourAPIKey";              # Get this from your 'profile' page in the Octopus web portal
$endpoint = New-Object Octopus.Client.OctopusServerEndpoint($server, $apiKey)
$repository = New-Object Octopus.Client.OctopusRepository($endpoint)
$roleName = "Project Deployer"
$spaceName = ""
$spaceId = $repository.Spaces.FindByName($spaceName)

# Get specific role
$role = $repository.UserRoles.FindByName($roleName)

# Get all the teams
$teams = $repository.Teams.GetAll()

# Check if spaceid has a value
if (![string]::IsNullOrEmpty($spaceName))
{
    # Limit teams to the specified space
    $teams = $teams | Where-Object {$_.SpaceId -eq $spaceId.Id}
}

# Loop through the teams
foreach ($team in $teams)
{
    # Get all associated user roles
    $scopedUserRoles = $repository.Teams.GetScopedUserRoles($team)

    # Loop through the scoped user roles
    foreach ($scopedUserRole in $scopedUserRoles)
    {
        # Check role id
        if ($scopedUserRole.UserRoleId -eq $role.Id)
        {
            # Display the team name
            Write-Output "Team: $($team.Name)"

            # Loop through the members
            foreach ($member in $team.MemberUserIds)
            {
                # Get the user account
                $user = $repository.Users.GetAll() | Where-Object {$_.Id -eq $member}
                
                # Display
                Write-Output "$($user.DisplayName)"
            }

             Write-Output "External security groups: $($team.ExternalSecurityGroups.Id)"
        }
    }
}