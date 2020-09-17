# You can get this dll from your Octopus Server/Tentacle installation directory or from
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
    $runbook = $repositoryForSpace.Runbooks.FindMany({param($r) $r.Name -eq $runbookName}) | Where-Object {$_.ProjectId -eq $project.Id}

    # Get the runbook process
    $runbookProcess = $repositoryForSpace.RunbookProcesses.Get($runbook.RunbookProcessId)

    # Gather selected packages
    $selectedPackages = @()
    foreach ($step in $runbookProcess.Steps)
    {
        # Loop through actions
        foreach ($action in $step.Actions)
        {
            # Check to see if action references packages
            if ($null -ne $action.Packages)
            {
                # Loop through packages
                foreach ($package in $action.Packages)
                {
                    # Get reference to feed
                    $feed = $repositoryForSpace.Feeds.Get($package.FeedId)
                    
                    # Check to see if built in
                    if ($feed.Id -eq "feeds-builtin")
                    {
                        # Get package version
                        $packageVersion = $repositoryForSpace.BuiltInPackageRepository.ListPackages($package.PackageId).Items[0].Version

                        # Create selected package object
                        $selectedPackage = New-Object Octopus.Client.Model.SelectedPackage
                        $selectedPackage.ActionName = $action.Name
                        $selectedPackage.PackageReferenceName = ""
                        $selectedPackage.StepName = $step.Name
                        $selectedPackage.Version = $packageVersion

                        # Add to collection
                        $selectedPackages += $selectedPackage
                    }
                }
            }
        }
    }

    # Create new runbook snapshot resource object
    $runbookSnapshot = New-Object Octopus.Client.Model.RunbookSnapshotResource
    $runbookSnapshot.Name = $snapshotName
    $runbookSnapshot.ProjectId = $project.Id
    $runbookSnapshot.RunbookId = $runbook.Id
    $runbookSnapshot.SpaceId = $space.Id
    
    # Add selected packages
    foreach ($item in $selectedPackages)
    {
        # Add to collection
        $runbookSnapshot.SelectedPackages.Add($item)
    }

    # Create the snapshot
    $snapshot = $repositoryForSpace.RunbookSnapshots.Create($runbookSnapshot)

    # Publish snapshot
    $runbook.PublishedRunbookSnapshotId = $snapshot.Id
    $repositoryForSpace.Runbooks.Modify($runbook)
}
catch
{
    Write-Host $_.Exception.Message
}