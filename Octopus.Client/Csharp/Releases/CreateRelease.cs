// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-APIKEY";
var spaceName = "default";
string projectName = "MyProject";
string channelName = "Default";
string releaseVersion = "1.0.0.3";

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

    // Get channel
    var channel = repositoryForSpace.Channels.FindOne(r => r.ProjectId == project.Id && r.Name == channelName);

    // Get deployment process
    var deploymentProcess = repositoryForSpace.DeploymentProcesses.Get(project.DeploymentProcessId);

    // Gather selected packages
    List<Octopus.Client.Model.SelectedPackage> selectedPackages = new List<SelectedPackage>();
    foreach (var step in deploymentProcess.Steps)
    {
        // Loop through actions
        foreach (var action in step.Actions)
        {
            // Check to see if packages are in this action
            if (action.Packages != null)
            {
                // Loop through packages
                foreach (var package in action.Packages)
                {
                    // Get feed
                    var feed = repositoryForSpace.Feeds.Get(package.FeedId);

                    // Check to see if it's built in
                    if (feed.FeedType == FeedType.BuiltIn)
                    {
                        // Get the package version
                        var packageVersion = repositoryForSpace.BuiltInPackageRepository.ListPackages(package.PackageId).Items[0].Version;

                        // Create selected package object
                        Octopus.Client.Model.SelectedPackage selectedPackage = new SelectedPackage();
                        selectedPackage.ActionName = action.Name;
                        selectedPackage.PackageReferenceName = package.PackageId;
                        selectedPackage.Version = packageVersion;

                        // Add to list
                        selectedPackages.Add(selectedPackage);
                    }
                }
            }
        }
    }

    // Create release object
    Octopus.Client.Model.ReleaseResource release = new ReleaseResource();
    release.ChannelId = channel.Id;
    release.ProjectId = project.Id;
    release.Version = releaseVersion;

    // Add packages
    foreach (var selectedPackage in selectedPackages)
    {
        release.SelectedPackages.Add(selectedPackage);
    }

    // Create release
    repositoryForSpace.Releases.Create(release, false);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}