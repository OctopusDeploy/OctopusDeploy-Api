# You can get this dll from NuGet
# https://www.nuget.org/packages/Octopus.Client/
# Load octopus.client assembly
Add-Type -Path "path\to\Octopus.Client.dll"

# Octopus variables
$octopusURL = "https://youroctopusurl"
$octopusAPIKey = "API-KEY"
$spaceName = "default"

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURL, $octopusAPIKey
$repository = New-Object Octopus.Client.OctopusRepository $endpoint
$client = New-Object Octopus.Client.OctopusClient $endpoint

try
{
    # Get space
    $space = $repository.Spaces.FindByName($spaceName)
    $repositoryForSpace = $client.ForSpace($space)

    # Get project
    $projects = $repositoryForSpace.Projects.GetAll()

    # Loop through projects
    foreach ($project in $projects)
    {
        # Get deployment process
        $deploymentProcess = $repositoryForSpace.DeploymentProcesses.Get($project.DeploymentProcessId)

        # Check for emtpy process
        if (($null -eq $deploymentProcess.Steps) -or ($deploymentProcess.Steps.Count -eq 0))
        {
            # Delete project
            $repositoryForSpace.Projects.Delete($project)
        }
    }
}
catch
{
    Write-Host $_.Exception.Message
}