// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

var octopusURL = "https://your.octopus.app";
var octopusAPIKey = "API-YOUR-KEY";
var spaceName = "Default";
var projectGroupName = "MyProjectGroup";
var projectGroupDescription = "My Description";

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

// Get space
var space = repository.Spaces.FindByName(spaceName);
var spaceRepository = client.ForSpace(space);

// Create project group object
var projectGroup = new Octopus.Client.Model.ProjectGroupResource();
projectGroup.Description = projectGroupDescription;
projectGroup.Name = projectGroupName;
projectGroup.EnvironmentIds = null;
projectGroup.RetentionPolicyId = null;

// Create the project group
spaceRepository.ProjectGroups.Create(projectGroup);