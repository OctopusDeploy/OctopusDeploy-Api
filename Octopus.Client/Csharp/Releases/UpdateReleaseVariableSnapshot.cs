// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;
var spaceName = "default";
string projectName = "MyProject";
string channelName = "Default";
string releaseVersion = "1.0.0.0";

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

    // Get release
    var release = repositoryForSpace.Releases.FindOne(r => r.ProjectId == project.Id && r.ChannelId == channel.Id && r.Version == releaseVersion);

    // Update variable snapshot
    repositoryForSpace.Releases.SnapshotVariables(release);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}