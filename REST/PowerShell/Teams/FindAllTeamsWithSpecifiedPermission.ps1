<#
.SYNOPSIS
This script returns all teams in an Octopus Deploy Space that have roles with the "DeploymentCreate" permission, either scoped to a specified environment or unscoped (applying to all environments).
>The "DeploymentCreate" permission can be changed to any permission found on any of the User Role overview screens.
>The "Production" environment can be changed to any of the environments in your Space.

.PREREQUISITES
1. Replace "<API_KEY>" with your actual API key (this API key must be for an Administrator account)
2. Replace "https://<OCTOPUS_URL>" with your Octopus Server URL
3. Replace "<SPACE_ID>" with the correct Space ID (found in the URL)

.EXAMPLE OUTPUT
Teams using roles with the 'DeploymentCreate' permission scoped to 'Production' or unscoped:
Product team (Roles: Project deployer, Deployment creator)
Space Managers (Roles: Space manager)
#>

$apiKey = "<API_KEY>"
$octopusBaseUrl = "https://<OCTOPUS_URL>"
$spaceId = "<SPACE_ID>"     #i.e. - "Spaces-17"

$permission = "DeploymentCreate"
$environmentName = "Production"
$headers = @{ "X-Octopus-ApiKey" = $apiKey }

# Get Environment ID
$environmentsUri = "$octopusBaseUrl/api/$spaceId/environments"
$environments = Invoke-RestMethod -Method Get -Uri $environmentsUri -Headers $headers
$environmentId = $environments.Items | Where-Object { $_.Name -eq $environmentName } | Select-Object -ExpandProperty Id

if (-not $environmentId) {
    Write-Output "Environment '$environmentName' not found."
    exit
}

# Get user roles with the specified permission
$userRolesUri = "$octopusBaseUrl/api/userroles"
$userRoles = Invoke-RestMethod -Method Get -Uri $userRolesUri -Headers $headers
$rolesWithPermission = $userRoles.Items | Where-Object { $permission -in $_.GrantedSpacePermissions } | Select-Object Id, Name

if ($rolesWithPermission.Count -eq 0) {
    Write-Output "No user roles found with the '$permission' permission."
    exit
}

$teamRolesMap = @{}

# Get all teams with that role(s) that are unscoped or scoped to the specified environment
$teamsUri = "$octopusBaseUrl/api/$spaceId/teams"
$teams = Invoke-RestMethod -Method Get -Uri $teamsUri -Headers $headers

foreach ($team in $teams.Items) {
    $teamRolesUri = "$octopusBaseUrl/api/$spaceId/teams/$($team.Id)/scopeduserroles"
    $teamRoles = Invoke-RestMethod -Method Get -Uri $teamRolesUri -Headers $headers
    
    foreach ($role in $teamRoles.Items) {
        $matchedRole = $rolesWithPermission | Where-Object { $_.Id -eq $role.UserRoleId }

        if ($matchedRole) {
            # Check if role is unscoped or scoped to the specified environment
            if (-not $role.EnvironmentIds -or $role.EnvironmentIds -contains $environmentId) {
                if (-not $teamRolesMap.ContainsKey($team.Name)) {
                    $teamRolesMap[$team.Name] = New-Object System.Collections.ArrayList
                }
                # Prevent duplication of teams
                if (-not $teamRolesMap[$team.Name].Contains($matchedRole.Name)) {
                    $teamRolesMap[$team.Name].Add($matchedRole.Name) | Out-Null
                }
            }
        }
    }
}

# Output team names and corresponding roles per team
if ($teamRolesMap.Count -eq 0) {
    Write-Output "No teams found using roles with the '$permission' permission scoped to '$environmentName' or unscoped."
} else {
    Write-Output "Teams using roles with the '$permission' permission scoped to '$environmentName' or unscoped:"
    foreach ($teamName in $teamRolesMap.Keys) {
        $rolesList = $teamRolesMap[$teamName] -join ', '
        Write-Output "$teamName (Roles: $rolesList)"
    }
}
