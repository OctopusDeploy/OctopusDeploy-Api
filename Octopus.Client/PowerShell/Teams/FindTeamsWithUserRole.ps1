# You can reference this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/

Add-Type -Path 'Octopus.Client.dll' 

$OctopusUrl = "" # example https://myoctopus.something.com
$APIKey = "" # example API-XXXXXXXXXXXXXXXXXXXXXXXXXXX
$roleName = "System administrator"

$endpoint = new-object Octopus.Client.OctopusServerEndpoint $OctopusUrl,$APIKey 
$repository = new-object Octopus.Client.OctopusRepository $endpoint

## Next find the roleId for the Role name
$userRoleId = $repository.UserRoles.FindOne({param($r) if ($r.Name -eq $roleName){$true}}).Id
Write-Host "The userRoleId for $roleName is $userRoleId"

## Next, let's find the teams
$teamsList = $repository.Teams.FindAll()
$targetTeams = @()

## Finally, loop through each teams scoped user roles and find the one we are searching for
foreach ($team in $teamsList) {
    
    $teamScopedUserRoles = $repository.Teams.GetScopedUserRoles($team);
    $roleFilter = @($teamScopedUserRoles | Where {$_.UserRoleId -eq $userRoleId})
    if($roleFilter.Count -gt 0) {
        $targetTeams+=$team.Name
    }
}
Write-Host
Write-Host "Teams with userRole '$roleName' are:"
$targetTeams