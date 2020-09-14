// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-YOURAPIKEY";
string spaceName = "default";
string tenantName = "MyTenant";
string[] projectNames = { "MyProject" };
string[] environmentNames = { "Development", "Production" };
string[] tenantTags = { "MyTagSet/Beta", "MyTagSet/Stable" };

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

try
{
    // Get space
    var space = repository.Spaces.FindByName(spaceName);
    var repositoryForSpace = client.ForSpace(space);

    // Get projects
    var projects = repositoryForSpace.Projects.FindByNames(projectNames);

    // Get environments
    var environments = repositoryForSpace.Environments.FindByNames(environmentNames);

    // Create projectenvironments
    Octopus.Client.Model.ReferenceCollection projectEnvironments = new ReferenceCollection();
    foreach (var environment in environments)
    {
        projectEnvironments.Add(environment.Id);
    }

    // Create tenant object
    Octopus.Client.Model.TenantResource tenant = new TenantResource();
    tenant.Name = tenantName;

    foreach (string tenantTag in tenantTags)
    {
        tenant.TenantTags.Add(tenantTag);
    }

    foreach (var project in projects)
    {
        tenant.ProjectEnvironments.Add(project.Id, projectEnvironments);
    }

    // Create tenant
    repositoryForSpace.Tenants.Create(tenant);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}