# You can get this dll from NuGet
# https://www.nuget.org/packages/Octopus.Client/
# Load octopus.client assembly
Add-Type -Path "path\to\Octopus.Client.dll"

# Octopus variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$spaceName = "default"
$projectName = "MyProject"
$runbookName = "MyRunbook"
$snapshotName = "Snapshot 9PNENH7"

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

    # Get runbook
    $runbook = $repositoryForSpace.Runbooks.FindByName($project, $runbookName)
    
    # Get the runbook snapshot
    $runbookSnapshot = $repositoryForSpace.RunbookSnapshots.FindOne({param($r) $r.Name -eq $snapshotName -and $r.ProjectId -eq $project.Id})

    # Publish snapshot
    $runbook.PublishedRunbookSnapshotId = $runbookSnapshot.Id
    $repositoryForSpace.Runbooks.Modify($runbook)
}
catch
{
    Write-Host $_.Exception.Message
}