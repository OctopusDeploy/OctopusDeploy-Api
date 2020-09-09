# You can reference this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/

Add-Type -Path "c:\octopus.client\Octopus.Client.dll"

# Octopus variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$spaceName = "default"
$userRoleName = "Deployment creator"

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURL, $octopusAPIKey
$repository = New-Object Octopus.Client.OctopusRepository $endpoint
$client = New-Object Octopus.Client.OctopusClient $endpoint

try
{
    # Get space
    $space = $repository.Spaces.FindByName($spaceName)
    $repositoryForSpace = $client.ForSpace($space)

    # Get team
    $teams = $repositoryForSpace.Teams.FindAll()

    # Get user role
    $userRole = $repositoryForSpace.UserRoles.FindByName($userRoleName)
    
    # Loop through teams
    $teamNames = @()
    foreach ($team in $teams)
    {
        # Get scopeduserrole
        $scopedUserRole = $repositoryForSpace.Teams.GetScopedUserRoles($team) | Where-Object {$_.UserRoleId -eq $userRole.Id}

        # Check for null
        if ($null -ne $scopedUserRole)
        {
            # Add to list
            $teamNames += $team.Name
        }
    }

    # Loop through results
    Write-Host "The following teams are using role $($userRoleName):"
    foreach ($teamName in $teamNames)
    {
        Write-Host "$teamName"
    }

}
catch
{
    Write-Host $_.Exception.Message
}