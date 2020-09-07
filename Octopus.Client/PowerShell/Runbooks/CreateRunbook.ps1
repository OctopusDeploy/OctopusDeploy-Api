# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
# Load octopus.client assembly
Add-Type -Path "path\to\Octopus.Client.dll"

# Octopus variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$spaceName = "default"
$projectName = "MyProject"
$runbookName = "MyRunbook"

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

    # Create runbook retention object
    $runbookRetentionPolicy = New-Object Octopus.Client.Model.RunbookRetentionPeriod
    $runbookRetentionPolicy.QuantityToKeep = 100
    $runbookRetentionPolicy.ShouldKeepForever = $false


    # Create runbook object
    $runbook = New-Object Octopus.Client.Model.RunbookResource
    $runbook.Name = $runbookName
    $runbook.ProjectId = $project.Id
    $runbook.RunRetentionPolicy = $runbookRetentionPolicy
    
    # Save
    $repositoryForSpace.Runbooks.Create($runbook)
}
catch
{
    Write-Host $_.Exception.Message
}