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
var projectName = "MyProject";
var environmentNameList = new string[] { "Environment", "List"};
string[] tenantTag = new string[] { "TagSet/Tag" }; // "TENANT TAG TO FILTER ON" Format = [Tenant Tag Set Name]/[Tenant Tag] "Tenant Type/Customer"
bool whatIf = false;
int maxNumberOfTenants = 1;
int tenantsUpdated = 0;

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

// Get space
var space = repository.Spaces.FindByName(spaceName);
var spaceRepository = client.ForSpace(space);

// Get project
var project = spaceRepository.Projects.FindByName(projectName);

// Get tenants by tag
var tenants = spaceRepository.Tenants.FindAll("", tenantTag, 1000);

// Get environment objects
var environments = new System.Collections.Generic.List<Octopus.Client.Model.EnvironmentResource>();
foreach (string environmentName in environmentNameList)
{
    var environment = spaceRepository.Environments.FindByName(environmentName);
    if (environment != null)
    {
        environments.Add(environment);
    }
    else
    {
        Console.WriteLine(string.Format("{0} not found!", environmentName));
    }
}

// Loop through tenants
foreach (var tenant in tenants)
{
    bool tenantUpdated = false;
    if(tenant.ProjectEnvironments == null || tenant.ProjectEnvironments.Count == 0)
    {
        // Add project/environments
        tenant.ConnectToProjectAndEnvironments(project, environments.ToArray());
        tenantUpdated = true;
    }
    else
    {
        // Get project connected environments
        System.Collections.Generic.Dictionary<string, ReferenceCollection> projectEnvironments = new System.Collections.Generic.Dictionary<string, Octopus.Client.Model.ReferenceCollection>(tenant.ProjectEnvironments.Where(e => e.Key == project.Id));

        // Compare what's connected to list of environments to connect
        foreach (var environment in environments)
        {
            if (!projectEnvironments[project.Id].Contains(environment.Id))
            {
                tenant.ProjectEnvironments[project.Id].Add(environment.Id);
                tenantUpdated = true;
            }
        }
    }

    // Check to see if tenant was updated
    if (tenantUpdated)
    {
        if (whatIf)
        {
            Console.WriteLine(tenant);
        }
        else
        {
            // Update tenant
            spaceRepository.Tenants.Modify(tenant);
        }

        // Increment updated counter
        tenantsUpdated++;
    }

    // Check to see if we've reached the max number of updated
    if (tenantsUpdated == maxNumberOfTenants)
    {
        // Get outta here!
        break;
    }
}