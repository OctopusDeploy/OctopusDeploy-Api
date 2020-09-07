// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-YOURAPIKEY";

var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);

var spaceName = "Default";
var projectName = "Your Project Name";
var channelName = "Default";
var environmentName = "Dev";
var tenantNames = new string[] { "Customer A Name", "Customer B Name" };

try
{
    // Get the space to work in
    var space = repository.Spaces.FindByName(spaceName);
    Console.WriteLine($"Using Space named {space.Name} with id {space.Id}");

    // Create space specific repository
    var repositoryForSpace = repository.ForSpace(space);

    // Get project by name
    var project = repositoryForSpace.Projects.FindByName(projectName);
    Console.WriteLine($"Using Project named {project.Name} with id {project.Id}");

    // Get channel by name
    var channel = repositoryForSpace.Channels.FindByName(project, channelName);
    Console.WriteLine($"Using Channel named {channel.Name} with id {channel.Id}");

    // Get environment by name
    var environment = repositoryForSpace.Environments.FindByName(environmentName);
    Console.WriteLine($"Using Environment named {environment.Name} with id {environment.Id}");

    // Get the deployment process template
    Console.WriteLine("Fetching deployment process template");
    var process = repositoryForSpace.DeploymentProcesses.Get(project.DeploymentProcessId);
    var template = repositoryForSpace.DeploymentProcesses.GetTemplate(process, channel);

    var release = new Octopus.Client.Model.ReleaseResource
    {
        ChannelId = channel.Id,
        ProjectId = project.Id,
        Version = template.NextVersionIncrement
    };

    // Set the package version to the latest for each package
    // If you have channel rules that dictate what versions can be used
    //  you'll need to account for that by overriding the selected package version
    Console.WriteLine("Getting action package versions");
    foreach (var package in template.Packages)
    {

        var feed = repositoryForSpace.Feeds.Get(package.FeedId);
        var latestPackage = repositoryForSpace.Feeds.GetVersions(feed, new[] { package.PackageId }).FirstOrDefault();

        var selectedPackage = new Octopus.Client.Model.SelectedPackage
        {
            ActionName = package.ActionName,
            Version = latestPackage.Version
        };

        Console.WriteLine($"Using version {latestPackage.Version} for step {package.ActionName} package {package.PackageId}");

        release.SelectedPackages.Add(selectedPackage);
    }

    // # Create release
    release = repositoryForSpace.Releases.Create(release, false); // pass in $true if you want to ignore channel rules

    var tenants = repositoryForSpace.Tenants.FindByNames(tenantNames);

    foreach (var tenant in tenants)
    {
        // # Create deployment
        var deployment = new Octopus.Client.Model.DeploymentResource
        {
            ReleaseId = release.Id,
            EnvironmentId = environment.Id,
            TenantId = tenant.Id
        };

        Console.WriteLine($"Creating deployment for release {release.Version} of project {projectName} to environment {environmentName} and tenant {tenant.Name}");
        deployment = repositoryForSpace.Deployments.Create(deployment);
    }
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
}