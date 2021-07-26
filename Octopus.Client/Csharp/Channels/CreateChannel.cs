// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

var octopusURL = "https://YourURL";
var octopusAPIKey = "API-YourAPIKey";
var spaceName = "Default";
var projectName = "MyProject";
var channelName = "NewChannel";

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

// Get space
var space = repository.Spaces.FindByName(spaceName);
var spaceRepository = client.ForSpace(space);

// Get project
var project = spaceRepository.Projects.FindByName(projectName);

// Create channel object
var channel = new Octopus.Client.Model.ChannelResource();
channel.Name = channelName;
channel.ProjectId = project.Id;
channel.SpaceId = space.Id;

spaceRepository.Channels.Create(channel);