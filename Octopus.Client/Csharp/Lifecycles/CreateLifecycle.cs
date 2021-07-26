// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;
using System;
using System.Linq;
// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

var octopusURL = "https://YourURL";
var octopusAPIKey = "API-YourAPIKey";
var spaceName = "Default";
var lifecycleName = "MyLifecycle";

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

// Get space
var space = repository.Spaces.FindByName(spaceName);
var spaceRepository = client.ForSpace(space);

if (null == spaceRepository.Lifecycles.FindByName(lifecycleName))
{
	// Create new lifecycle
	var lifecycle = new Octopus.Client.Model.LifecycleResource();
	lifecycle.Name = lifecycleName;
	spaceRepository.Lifecycles.Create(lifecycle);
}
else
{
	Console.Write(string.Format("{0} already exists.", lifecycleName));
}