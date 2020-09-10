// If using .net Core, be sure to add the NuGet package of System.Security.Permissions
//#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

// Declare working variables
var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-YOURAPIKEY";
var spaceName = "default";

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

try
{
    // Get space
    var space = repository.Spaces.FindByName(spaceName);
    var repositoryForSpace = client.ForSpace(space);

    // Loop through projets
    foreach (var project in repositoryForSpace.Projects.GetAll())
    {
        var variableSet = repositoryForSpace.VariableSets.Get(project.VariableSetId);

        foreach (var variable in variableSet.Variables)
        {
            if (variable.IsSensitive)
            {
                variable.Value = string.Empty;
            }
        }

        repositoryForSpace.VariableSets.Modify(variableSet);
    }

    // Loop through library sets
    foreach (var librarySet in repositoryForSpace.LibraryVariableSets.FindAll())
    {
        var variableSet = repositoryForSpace.VariableSets.Get(librarySet.VariableSetId);

        foreach (var variable in variableSet.Variables)
        {
            if (variable.IsSensitive)
            {
                variable.Value = string.Empty;
            }
        }

        repositoryForSpace.VariableSets.Modify(variableSet);
    }
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
}