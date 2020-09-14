// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-YOURAPIKEY";
var spaceName = "Default";
var tenantName = "TenantName";
var projectVariableTemplateName = "TemplateName";
var variableNewValue = "NewValue";

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

try
{
    // Get space
    var space = repository.Spaces.FindByName(spaceName);
    var repositoryForSpace = client.ForSpace(space);

    // Get tenant
    var tenant = repositoryForSpace.Tenants.FindByName(tenantName);

    // Get tenant variables
    var variables = repositoryForSpace.Tenants.GetVariables(tenant);

    // Loop through tenant variables
    foreach (var projectKey in variables.ProjectVariables.Keys)
    {
        var project = variables.ProjectVariables[projectKey];
        var projectName = project.ProjectName;
        Console.WriteLine("Working on Project: {0} ({1})", projectName, projectKey);

        // Get project template ID.
        var variableTemplateResource = project.Templates.FirstOrDefault(t => t.Name == projectVariableTemplateName);

        if (variableTemplateResource != null)
        {
            var variableTemplateId = variableTemplateResource.Id;
            Console.WriteLine("Found templateid for template: {0} of {1}", projectVariableTemplateName, variableTemplateId);

            // Loop through each of the connected environments
            foreach (var envKey in project.Variables.Keys)
            {
                // Find variable which matches the current connected environment.
                var templateEnvironmentVariable = project.Variables[envKey].Where(x => x.Key == variableTemplateId).Select(x => x.Value).FirstOrDefault();
                if (templateEnvironmentVariable == null)
                {
                    Console.WriteLine("No value found for {0}, adding in new Value={1} for Environment '{2}' ", projectVariableTemplateName, variableNewValue, envKey);
                    project.Variables[envKey][variableTemplateId] = new PropertyValueResource(variableNewValue);
                }
                else
                {
                    // Get current value
                    var currentValue = templateEnvironmentVariable.Value;
                    Console.WriteLine("Found {0} in Environment '{1}' with value {2}", projectVariableTemplateName, envKey, currentValue);

                    // Set the new value for this connected environment
                    project.Variables[envKey][variableTemplateId] = new PropertyValueResource(variableNewValue);
                }
            }
        }
        else
        {
            Console.WriteLine("Couldnt find project template: {0} for project {1}", projectVariableTemplateName, projectName);
        }
    }

    // Update the variables with the new value
    repositoryForSpace.Tenants.ModifyVariables(tenant, variables);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}