# You can get this dll from NuGet
# https://www.nuget.org/packages/Octopus.Client/
# Load octopus.client assembly
Add-Type -Path "c:\octopus.client\Octopus.Client.dll"

# Octopus variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$spaceName = "default"
$projectName = "MyProject"

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURL, $octopusAPIKey
$repository = New-Object Octopus.Client.OctopusRepository $endpoint
$client = New-Object Octopus.Client.OctopusClient $endpoint

try
{
    # Get space
    $space = $repository.Spaces.FindByName($spaceName)
    $repositoryForSpace = $client.ForSpace($space)

    # Get project
    $project = $repositoryForSpace.Projects.FindByName($projectName)

    # Get project triggers
    $projectTriggers = $repositoryForSpace.Projects.GetAllTriggers($project)

    # Loop through triggers
    foreach ($projectTrigger in $projectTriggers)
    {
        # Disable trigger
        $projectTrigger.IsDisabled = $true
        $repositoryForSpace.ProjectTriggers.Modify($projectTrigger) | Out-Null
    }
}
catch
{
    Write-Host $_.Exception.Message
}