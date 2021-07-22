// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;
using System;
using System.Linq;

// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

var octopusURL = "https://YourURL";
var octopusAPIKey = "API-YourAPIKey";
var spaceName = "Default";
var projectName = "MyProject";
var runbookName = "MyRunbook";

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

// Get space
var space = repository.Spaces.FindByName(spaceName);
var spaceRepository = client.ForSpace(space);

// Get project
var project = spaceRepository.Projects.FindByName(projectName);

// Get runbook
var runbook = spaceRepository.Runbooks.FindByName(project, runbookName);

// Get runbook snapshot tempalte
var runbookSnapshotTemplate = spaceRepository.Runbooks.GetRunbookSnapshotTemplate(runbook);

// Create runbook snapshot
var runbookSnapshot = new Octopus.Client.Model.RunbookSnapshotResource(project.Id);
runbookSnapshot.RunbookId = runbook.Id;
runbookSnapshot.Name = runbookSnapshotTemplate.NextNameIncrement;
runbookSnapshot.SpaceId = space.Id;

// Add any referenced packages
foreach (var package in runbookSnapshotTemplate.Packages)
{
    // Get the feed
    var feed = spaceRepository.Feeds.Get(package.FeedId);
    var latestPackage = spaceRepository.Feeds.GetVersions(feed, (new string[] { package.PackageId }));

    // Create new selected package object
    var selectedPackage = new Octopus.Client.Model.SelectedPackage(package.ActionName, package.PackageReferenceName, latestPackage[0].Version);

    // Add to runbook snapshot
    runbookSnapshot.SelectedPackages.Add(selectedPackage);
}

// Publish snapshot
runbookSnapshot = spaceRepository.RunbookSnapshots.Create(runbookSnapshot);
runbook.PublishedRunbookSnapshotId = runbookSnapshot.Id;
spaceRepository.Runbooks.Modify(runbook); 