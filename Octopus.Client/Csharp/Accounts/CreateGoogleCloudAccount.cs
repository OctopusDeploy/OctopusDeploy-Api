// Note: This script will only work with Octopus 2021.2 and higher.
// It also requires version 11.3.3355 or higher of the Octopus.Client library

// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

var OctopusURL = "https://your.octopus.app";
var OctopusAPIKey = "API-YOURAPIKEY";
string spaceName = "Default";

// Octopus Account name
string accountName = "My Google Cloud Account";

// Octopus Account Description
string accountDescription = "A Google Cloud account for my project";

// Tenant Participation e.g. Tenanted, or, Untenanted, or TenantedOrUntenanted
Octopus.Client.Model.TenantedDeploymentMode octopusAccountTenantParticipation = Octopus.Client.Model.TenantedDeploymentMode.TenantedOrUntenanted;

// Google Cloud JSON key file
string jsonKeyPath = @"/path/to/jsonkeyfile.json";
string jsonKeyBase64 = "";

// (Optional) Tenant tags e.g.: "AWS Region/California"
Octopus.Client.Model.ReferenceCollection octopusAccountTenantTags = new ReferenceCollection();
// (Optional) Tenant Ids e.g.: "Tenants-101"
Octopus.Client.Model.ReferenceCollection octopusAccountTenantIds = new ReferenceCollection();
// (Optional) Environment Ids e.g.: "Environments-1"
Octopus.Client.Model.ReferenceCollection octopusAccountEnvironmentIds = new ReferenceCollection();

if (!File.Exists(jsonKeyPath))
{
    Console.WriteLine("The Json Key file was not found at '{0}", jsonKeyPath);
    return;
}
else
{
    string jsonContent = File.ReadAllText(jsonKeyPath);
    jsonKeyBase64 = Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes(jsonContent));
}

try
{
    // Create repository object
    var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
    var repository = new OctopusRepository(endpoint);
    var client = new OctopusClient(endpoint);

    // Get space
    var space = repository.Spaces.FindByName(spaceName);
    var repositoryForSpace = client.ForSpace(space);

    // Create Google Cloud Account object
    var googleCloudAccount = new Octopus.Client.Model.Accounts.GoogleCloudAccountResource();

    googleCloudAccount.Name = accountName;
    googleCloudAccount.Description = accountDescription;
    googleCloudAccount.JsonKey = new SensitiveValue
    {
        NewValue = jsonKeyBase64,
        HasValue = true
    };
    googleCloudAccount.TenantedDeploymentParticipation = octopusAccountTenantParticipation;
    googleCloudAccount.TenantIds = octopusAccountTenantIds;
    googleCloudAccount.EnvironmentIds = octopusAccountEnvironmentIds;
    
    repositoryForSpace.Accounts.Create(googleCloudAccount);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}