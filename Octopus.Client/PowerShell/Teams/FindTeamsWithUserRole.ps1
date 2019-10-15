$OctopusUrl = "" # example https://myoctopus.something.com
$APIKey = "" # example API-XXXXXXXXXXXXXXXXXXXXXXXXXXX
$spaceName = "Default"
$roleName = "System administrator"

$header = @{ "X-Octopus-ApiKey" = $APIKey }

## First we need to find the space
$spaceList = Invoke-RestMethod "$OctopusUrl/api/spaces?Name=$spaceName" -Headers $header
$spaceFilter = @($spaceList.Items | Where {$_.Name -eq $spaceName})
$spaceId = $spaceFilter[0].Id
Write-Host "The spaceId for Space Name $spaceName is $spaceId"

## Next find the roleId for the Role name
$userRoleList = Invoke-RestMethod "$OctopusUrl/api/userroles/all" -Headers $header
$userRoleFilter = @($userRoleList | Where {$_.Name -eq $roleName})
$userRoleId = $userRoleFilter[0].Id
Write-Host "The userRoleId for $roleName is $userRoleId"

## Next, let's find the teams
$teamsList = Invoke-RestMethod "$OctopusUrl/api/teams?spaces=$spaceId&includeSystem=true" -Headers $header 
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