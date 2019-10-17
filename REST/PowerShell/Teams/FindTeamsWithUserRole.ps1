$OctopusUrl = "" # example https://myoctopus.something.com
$APIKey = "" # example API-XXXXXXXXXXXXXXXXXXXXXXXXXXX
$roleName = "System administrator"

$header = @{ "X-Octopus-ApiKey" = $APIKey }

## First, let's find the roleId for the Role name
$userRoleList = Invoke-RestMethod "$OctopusUrl/api/userroles/all" -Headers $header
$userRoleFilter = @($userRoleList | Where {$_.Name -eq $roleName})
$userRoleId = $userRoleFilter[0].Id
Write-Host "The userRoleId for $roleName is $userRoleId"

## Next, let's find the teams
$teamsList = Invoke-RestMethod "$OctopusUrl/api/teams?includeSystem=true" -Headers $header 
$targetTeams = @()

## Finally, loop through each teams scoped user roles and find the one we are searching for
foreach ($team in $teamsList.Items) {
    $teamId = $team.Id
    $teamScopedUserRoles = Invoke-RestMethod  -UseBasicParsing "$OctopusUrl/api/teams/$teamId/scopeduserroles" -Headers $header
    $roleFilter = @($teamScopedUserRoles.Items | Where {$_.UserRoleId -eq $userRoleId})
    if($roleFilter.Count -gt 0) {
        $targetTeams+=$team.Name
    }
}
Write-Host
Write-Host "Teams with userRole '$roleName' are:"
$targetTeams