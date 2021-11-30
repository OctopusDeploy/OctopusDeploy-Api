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
var environmentName = "Dev";

try
{
    // Get the space to work in
    var space = repository.Spaces.FindByName(spaceName);
    Console.WriteLine($"Using Space named {space.Name} with id {space.Id}");

    // Create space specific repository
    var repositoryForSpace = repository.ForSpace(space);

    // Get environment
    var environment = repositoryForSpace.Environments.FindByName(environmentName);
	
    // Get paged list of deployments for that environment
    var deployments = new List<DeploymentResource>();
	repositoryForSpace.Deployments.Paginate(null, new[] { environment.Id }, page =>
	{
		deployments.AddRange(page.Items);
		return true;
	});
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
}