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
var valueBoundToOctoVariable = true;

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
            var variableTemplateIsSensitiveControlType = (variableTemplateResource.DisplaySettings.FirstOrDefault(ds => ds.Key == "Octopus.ControlType")).Value == "Sensitive";
            Console.WriteLine("Found templateid for template: {0} of {1}", projectVariableTemplateName, variableTemplateId);

            // Loop through each of the connected environments
            foreach (var envKey in project.Variables.Keys)
            {
                // Set null value in case not set
                project.Variables[envKey][variableTemplateId] = null;

                if (variableTemplateIsSensitiveControlType == true)
                {
                    if (valueBoundToOctoVariable == true)
                    {
                        Console.WriteLine("Adding in new text value (treating as octopus variable) in Environment '{0}' for {1}", envKey, projectVariableTemplateName);
                        project.Variables[envKey][variableTemplateId] = new PropertyValueResource(variableNewValue);
                    }
                    else
                    {
                        Console.WriteLine("Adding in new sensitive value = '********' in Environment '{0}' for {1}", envKey, projectVariableTemplateName);
                        var sensitiveValue = new SensitiveValue { HasValue = true, NewValue = variableNewValue };
                        project.Variables[envKey][variableTemplateId] = new PropertyValueResource(sensitiveValue);
                    }
                }
                else
                {
                    //Write-Host "Adding in new value = $newValue in Environment '$envKey' for $variableTemplateName"
                    Console.WriteLine("Adding in new value = '{0}' in Environment '{1}' for {2}", variableNewValue, envKey, projectVariableTemplateName);
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