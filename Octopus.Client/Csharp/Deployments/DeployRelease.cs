// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

string spaceName = "Default";
string projectName = "ProjectName";
string releaseVersion = "0.0.1";
string environmentName = "Development";

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

try
{
    // Get space
    var space = repository.Spaces.FindByName(spaceName);
    var repositoryForSpace = client.ForSpace(space);

    // Get Environment
    var environment = repositoryForSpace.Environments.FindByName(environmentName);
    
    // Get project
    var project = repositoryForSpace.Projects.FindByName(projectName);

    // Get release
    var release = repositoryForSpace.Projects.GetReleaseByVersion(project, releaseVersion);

    // Create deployment
    var deployment = new Octopus.Client.Model.DeploymentResource
    {
        ReleaseId = release.Id,
        EnvironmentId = environment.Id
    };
    
    deployment = repositoryForSpace.Deployments.Create(deployment);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}