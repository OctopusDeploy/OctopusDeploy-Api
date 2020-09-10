// If using .net Core, be sure to add the NuGet package of System.Security.Permissions
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working varibles
var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-YOURAPIKEY";
string spaceName = "default";
string projectName = "MyProject";
System.Collections.Hashtable variable = new System.Collections.Hashtable()
{
    { "Name", "MyVariable" },
    {"Value", "MyValue" },
    {"Type", "String" },
    {"IsSensitive", false }
};

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

try
{
    // Get space
    var space = repository.Spaces.FindByName(spaceName);
    var repositoryForSpace = client.ForSpace(space);

    // Get project
    var project = repositoryForSpace.Projects.FindByName(projectName);

    // Get project variables
    var projectVariables = repositoryForSpace.VariableSets.Get(project.VariableSetId);

    // Check to see if variable exists
    var variableToUpdate = projectVariables.Variables.FirstOrDefault(v => v.Name == (variable["Name"]).ToString());
    if (variableToUpdate == null)
    {
        // Create new variable object
        variableToUpdate = new Octopus.Client.Model.VariableResource();
        variableToUpdate.Name = variable["Name"].ToString();
        variableToUpdate.Value = variable["Value"].ToString();
        variableToUpdate.Type = (Octopus.Client.Model.VariableType)Enum.Parse(typeof(Octopus.Client.Model.VariableType), variable["Type"].ToString());
        variableToUpdate.IsSensitive = bool.Parse(variable["IsSensitive"].ToString());

        // Add to collection
        projectVariables.Variables.Add(variableToUpdate);
    }
    else
    {
        // Update value
        variableToUpdate.Value = variable["Value"].ToString();
    }

    // Update collection
    repositoryForSpace.VariableSets.Modify(projectVariables);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}