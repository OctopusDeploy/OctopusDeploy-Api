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
    // Get space+repo
    var space = repository.Spaces.FindByName(spaceName);
    var repositoryForSpace = client.ForSpace(space);

    // Get project
    var project = repositoryForSpace.Projects.FindByName(projectName);

    // Get channel
    var channel = repositoryForSpace.Channels.FindOne(r => r.ProjectId == project.Id && r.Name == channelName);

    // Create release object
    Octopus.Client.Model.ReleaseResource release = new ReleaseResource();
    release.ChannelId = channel.Id;
    release.ProjectId = project.Id;
    release.Version = releaseVersion;
    release.SelectedPackages = new List<Octopus.Client.Model.SelectedPackage>();

    // Get deployment process
    var deploymentProcess = repositoryForSpace.DeploymentProcesses.Get(project.DeploymentProcessId);

    // Get template
    var template = repositoryForSpace.DeploymentProcesses.GetTemplate(deploymentProcess, channel);

    // Loop through the deployment process packages and add to release payload
    foreach (var package in template.Packages)
    {
        // Get feed
        var feed = repositoryForSpace.Feeds.Get(package.FeedId);
        //var packageVersion = repositoryForSpace.BuiltInPackageRepository.ListPackages(package.PackageId).Items[0].Version;
        var packageVersion = repositoryForSpace.Feeds.GetVersions(feed, new[] { package.PackageId }).First().Version;

        // Create selected package object
        Octopus.Client.Model.SelectedPackage selectedPackage = new SelectedPackage();
        selectedPackage.ActionName = package.ActionName;
        selectedPackage.PackageReferenceName = package.PackageReferenceName;
        selectedPackage.Version = packageVersion;

        // Add to release
        release.SelectedPackages.Add(selectedPackage);
    }

    // Create release
    var releaseCreated = repositoryForSpace.Releases.Create(release, false);
    Console.WriteLine("Created release with version: {0}", releaseCreated.Version);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}