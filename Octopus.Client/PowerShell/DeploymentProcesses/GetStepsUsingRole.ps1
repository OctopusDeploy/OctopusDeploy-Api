# You can get this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path "path\to\Octopus.Client.dll"

# Octopus variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$spaceName = "default"
$roleName = "My role"

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURL, $octopusAPIKey
$repository = New-Object Octopus.Client.OctopusRepository $endpoint
$client = New-Object Octopus.Client.OctopusClient $endpoint

# Get space
$space = $repository.Spaces.FindByName($spaceName)
$repositoryForSpace = $client.ForSpace($space)

$projectList = $repositoryForSpace.Projects.GetAll()

"Looking for steps with the role $($roleName) in them..."

foreach($project in $projectList)
{
    # Get deployment process    
    $deploymentProcess = $repositoryForSpace.DeploymentProcesses.Get($project.DeploymentProcessId)

    # Loop through steps
    foreach ($step in $deploymentProcess.Steps)
    {
        if($step.properties.'Octopus.Action.TargetRoles' -and ($step.properties.'Octopus.Action.TargetRoles'.Value.Split(',') -Icontains $roleName ))
        {
            "Step [$($step.Name)] from project [$($project.Name)] is using the role [$($roleName )]"
        }
    }
}