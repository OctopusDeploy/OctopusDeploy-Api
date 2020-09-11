# You can get this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'path\to\Octopus.Client.dll'

$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint($octopusURL, $octopusAPIKey)
$repository = New-Object Octopus.Client.OctopusRepository($endpoint)

$spaceName = "New Space"
$description = "Space for the new, top secret project."
$managersTeams = @() # an array of team Ids to add to Space Managers
$managerTeamMembers = @() # an array of user Ids to add to Space Managers
$environments = @('Development', 'Test', 'Production')


$space = New-Object Octopus.Client.Model.SpaceResource -Property @{
    Name = $spaceName
    Description = $description
    SpaceManagersTeams = New-Object Octopus.Client.Model.ReferenceCollection($managersTeams)
    SpaceManagersTeamMembers = New-Object Octopus.Client.Model.ReferenceCollection($managerTeamMembers)
    IsDefault = $false
    TaskQueueStopped = $false
};

try {
    $space = $repository.Spaces.Create($space)
}
catch {
    Write-Host $_.Exception.Message
    exit
}

$repositoryForSpace = [Octopus.Client.OctopusRepositoryExtensions]::ForSpace($repository, $space)

foreach ($environmentName in $environments) {
    $environment = New-Object Octopus.Client.Model.EnvironmentResource -Property @{
        Name = $environmentName
    }

    try {
        $repositoryForSpace.Environments.Create($environment)
    }
    catch {
        Write-Host $_.Exception.Message
        exit
    }
}