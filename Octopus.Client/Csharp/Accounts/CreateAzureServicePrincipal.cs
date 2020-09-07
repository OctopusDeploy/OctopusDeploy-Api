// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

var OctopusURL = "https://youroctourl";
var OctopusAPIKey = "API-YOURAPIKEY";

// Azure specific details
string azureSubscriptionNumber = "Subscription-Guid";
string azureClientId = "Client-Guid";
string azureTenantId = "Tenant-Guid";
string azureSecret = "Secret";

// Octopus Account details
string octopusAccountName = "Azure Account";
string octopusAccountDescription = "My Azure Account";
Octopus.Client.Model.TenantedDeploymentMode octopusAccountTenantParticipation = Octopus.Client.Model.TenantedDeploymentMode.Untenanted;
Octopus.Client.Model.ReferenceCollection octopusAccountTenantTags = null;
Octopus.Client.Model.ReferenceCollection octopusAccountTenantIds = null;
Octopus.Client.Model.ReferenceCollection octopusAccountEnvironmentIds = null;
string spaceName = "default";

var endpoint = new OctopusServerEndpoint(OctopusURL, OctopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);
var azureAccount = new Octopus.Client.Model.Accounts.AzureServicePrincipalAccountResource();

try
{
    // Get space
    var space = repository.Spaces.FindByName(spaceName);
    var repositoryForSpace = client.ForSpace(space);

    // Fill in account details
    azureAccount.ClientId = azureClientId;
    azureAccount.TenantId = azureTenantId;
    azureAccount.SubscriptionNumber = azureSubscriptionNumber;
    azureAccount.Password = azureSecret;
    azureAccount.Name = octopusAccountName;
    azureAccount.Description = octopusAccountDescription;
    azureAccount.TenantedDeploymentParticipation = octopusAccountTenantParticipation;
    azureAccount.TenantTags = octopusAccountTenantTags;
    azureAccount.TenantIds = octopusAccountTenantIds;
    azureAccount.EnvironmentIds = octopusAccountEnvironmentIds;

    // Create account
    repositoryForSpace.Accounts.Create(azureAccount);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}