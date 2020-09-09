Add-Type -Path "path\to\Octopus.Client.dll"

# Octopus variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$spaceName = "default"
$environmentNames = @("Test", "Production")
$teamName = "MyTeam"
$userRoleName = "Deployment creator"

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURL, $octopusAPIKey
$repository = New-Object Octopus.Client.OctopusRepository $endpoint
$client = New-Object Octopus.Client.OctopusClient $endpoint
$environmentIds = @()

try
{
    # Get space
    $space = $repository.Spaces.FindByName($spaceName)
    $repositoryForSpace = $client.ForSpace($space)

    # Get team
    $team = $repositoryForSpace.Teams.FindByName($teamName)

    # Get user role
    $userRole = $repositoryForSpace.UserRoles.FindByName($userRoleName)
    
    # Get scopeduserrole
    $scopedUserRole = $repositoryForSpace.Teams.GetScopedUserRoles($team) | Where-Object {$_.UserRoleId -eq $userRole.Id}

    # Get environments
    $environments = $repositoryForSpace.Environments.GetAll() | Where-Object {$environmentNames -contains $_.Name}
    foreach ($environment in $environments)
    {
        # Add Id
        $scopedUserRole.EnvironmentIds.Add($environment.Id)
    }

    # Update the scoped user role object
    $repositoryForSpace.ScopedUserRoles.Modify($scopedUserRole)
}
catch
{
    Write-Host $_.Exception.Message
}