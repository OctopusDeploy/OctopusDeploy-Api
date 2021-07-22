// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-YOURAPIKEY";
string spaceName = "default";
string projectName = "MyProject";
string runbookName = "MyRunbook";

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

try
{
    // Get space
    var space = repository.Spaces.FindByName(spaceName);
    var repositoryForSpace = client.ForSpace(space);

    // Get project
    var project = repositoryForSpace.Projects.FindByName(projectName);

    // Get runbook
    var runbook = repositoryForSpace.Runbooks.FindByName(project, runbookName);

    // Get runbook process
    var runbookProcess = repositoryForSpace.RunbookProcesses.Get(runbook.RunbookProcessId);

    // Get runbook snapshot template
    var runbookSnapshotTemplate = repositoryForSpace.RunbookProcesses.GetTemplate(runbookProcess);

    // Create a runbook snapshot
    var runbookSnapshot = new RunbookSnapshotResource
    {
        ProjectId = project.Id,
        RunbookId = runbook.Id,
        Name = runbookSnapshotTemplate.NextNameIncrement,
        // Add optional notes next
        Notes = null,
        SelectedPackages = new List<Octopus.Client.Model.SelectedPackage>()
    };

    // Include latest built-in feed packages
    foreach (var package in runbookSnapshotTemplate.Packages)
    {
        if (package.FeedId == "feeds-builtin")
        {
            // Get latest package version
            var packages = repositoryForSpace.BuiltInPackageRepository.ListPackages(package.PackageId, take: 1);
            var latestPackage = packages.Items.FirstOrDefault();
            if (latestPackage == null)
            {
                throw new Exception("Couldnt find latest package for " + package.PackageId);
            }

            runbookSnapshot.SelectedPackages.Add(new SelectedPackage { ActionName = package.ActionName, Version = latestPackage.Version, PackageReferenceName = package.PackageReferenceName });
        }
    }

    // Create new snapshot
    var runbookPublishedSnapshot = repositoryForSpace.RunbookSnapshots.Create(runbookSnapshot, new { publish = true });

    // Re-retrieve runbook
    runbook = repositoryForSpace.Runbooks.Get(runbook.Id);

    // Assign the snapshot as the published one.
    runbook.PublishedRunbookSnapshotId = runbookPublishedSnapshot.Id;
    repositoryForSpace.Runbooks.Modify(runbook);
    Console.WriteLine("Published runbook snapshot: {0} ({1})", runbookPublishedSnapshot.Id, runbookPublishedSnapshot.Name);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    Console.ReadLine();
    return;
}