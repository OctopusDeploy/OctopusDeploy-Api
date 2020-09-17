// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-APIKEY";
string spaceName = "default";
string projectName = "MyProject";
string runbookName = "MyRunbook";
string snapshotName = "Snapshot 7PNENH8";

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
    var runbook = repositoryForSpace.Runbooks.FindMany(n => n.Name == runbookName && n.ProjectId == project.Id)[0];

    // Get runbook process
    var runbookProcess = repositoryForSpace.RunbookProcesses.Get(runbook.RunbookProcessId);

    // Gather selected packages
    List<Octopus.Client.Model.SelectedPackage> selectedPackages = new List<SelectedPackage>();
    foreach (var step in runbookProcess.Steps)
    {
        foreach (var action in step.Actions)
        {
            // Check for packages
            if (action.Packages != null)
            {
                // Loop through packages
                foreach (var package in action.Packages)
                {
                    // Get feed reference
                    var feed = repositoryForSpace.Feeds.Get(package.FeedId);

                    // Check to see if it's the built in one
                    if (feed.Id == "feeds-builtin")
                    {
                        // Get package version
                        var packageVersion = repositoryForSpace.BuiltInPackageRepository.ListPackages(package.PackageId).Items[0].Version;

                        // Create selected package object
                        Octopus.Client.Model.SelectedPackage selectedPackage = new SelectedPackage();
                        selectedPackage.ActionName = action.Name;
                        selectedPackage.PackageReferenceName = "";
                        selectedPackage.Version = packageVersion;

                        // Add to collection
                        selectedPackages.Add(selectedPackage);
                    }
                }
            }
        }
    }

    // Create new runbook snapshot resource object
    Octopus.Client.Model.RunbookSnapshotResource runbookSnapshot = new RunbookSnapshotResource();
    runbookSnapshot.Name = snapshotName;
    runbookSnapshot.ProjectId = project.Id;
    runbookSnapshot.RunbookId = runbook.Id;
    runbookSnapshot.SpaceId = space.Id;
    runbookSnapshot.SelectedPackages = selectedPackages;

    // Create snapshot
    var snapshot = repositoryForSpace.RunbookSnapshots.Create(runbookSnapshot);

    // Publish the snapshot
    runbook.PublishedRunbookSnapshotId = snapshot.Id;
    repositoryForSpace.Runbooks.Modify(runbook);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}