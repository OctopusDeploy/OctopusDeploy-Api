$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app/"
$octopusAPIKey = "API-KEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

# Provide the space name for the projects to check
$spaceName = "Default"
# Provide an optional list of project names to export.
$projectNames = @()

$octopusURL = $octopusURL.TrimEnd('/')

# Get Space
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -eq $spaceName }

# Cache all project groups
Write-Output "Retrieving all project groups"
$project_groups = @()
$response = $null
do {
  $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/$($space.Id)/projectgroups" }
  $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
  $project_groups += $response.Items
} while ($response.Links.'Page.Next')

# Cache all projects
Write-Output "Retrieving all projects"
$projects = @()
$response = $null
do {
  $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/$($space.Id)/projects" }
  $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
  $projects += $response.Items
} while ($response.Links.'Page.Next')

# Cache all teams
Write-Output "Retrieving all teams"
$teams = @()
$response = $null
do {
  $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/$($space.Id)/teams?spaces=$($space.Id)&includeSystem=true" }
  $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
  $teams += $response.Items
} while ($response.Links.'Page.Next')

# Cache all users
Write-Output "Retrieving all users"
$users = @()
$response = $null
do {
  $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/users" }
  $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
  $users += $response.Items
} while ($response.Links.'Page.Next')

# check for project names
if ($null -ne $projectNames -and $projectNames.Length -gt 0) {
  Write-Output "Filtering projects to just: $($projectNames -join ', ')"
  $projects = $projects | Where-Object { $projectNames -icontains $_.Name }
}

$teamScopedUserRoles = @{}
function Get-ScopedUserRolesForTeam($teamId, $spaceId) {
  $response = $null
  if ($null -ne $teamScopedUserRoles[$teamId]) {
    $response = $teamScopedUserRoles[$teamId] 
  }
  else {
    $scopedUserRolesForTeam = Invoke-RestMethod -Uri "$octopusURL/api/teams/$teamId/scopeduserroles" -Headers $header 
    $teamScopedUserRoles[$teamId] = $scopedUserRolesForTeam.Items
  }
  $itemsForSpace = $response | Where-Object { $_.SpaceId -eq $spaceId }
  return $itemsForSpace
}

# Main loop
foreach ($project_group in $project_groups) {
  Write-Output "Project Group: $($project_group.Name)"

  $projects_in_group = $projects | Where-Object { $_.ProjectGroupId -eq $project_group.Id }
  foreach ($project in $projects_in_group) {
    Write-Output "  Project: $($project.Name)"

    foreach ($team in $teams) {
      $scoped_user_roles = Get-ScopedUserRolesForTeam -teamId $team.Id -spaceId $space.Id
      $has_project_scoping = $scoped_user_roles | Where-Object { $_.ProjectIds -contains $project.Id }
      $has_project_group_scoping = $scoped_user_roles | Where-Object { $_.ProjectGroupIds -contains $project_group.Id }
      if ($has_project_scoping -or $has_project_group_scoping) {
        Write-Output "    Team: $($team.Name)"
        $team.MemberUserIds | ForEach-Object { 
          $userId = $_
          $user = $users | Where-Object { $_.Id -eq $userId } | Select-Object -First 1 
          Write-Host "      User: $($user.DisplayName)" -ForegroundColor Green
        }
      }
      
    }
  }
}
