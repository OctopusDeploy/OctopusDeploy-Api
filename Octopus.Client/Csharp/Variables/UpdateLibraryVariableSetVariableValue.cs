#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;
using System.Linq;

var octopusURL = "https://your.octopusdemos.app";
var octopusAPIKey = "API-YOURKEY";

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);
var spaceName = "Default";
string libraryVariableSetName = "MyLibraryVariableSet";
string variableName = "MyVariable";
string variableValue = "MyValue";

var space = repository.Spaces.FindByName(spaceName);
var repositoryForSpace = client.ForSpace(space);

Console.WriteLine(string.Format("Looking for library variable set '{0}'", libraryVariableSetName));

var librarySet = repositoryForSpace.LibraryVariableSets.FindByName(libraryVariableSetName);

if (null == librarySet)
{
    throw new Exception(string.Format("Library variable not found with name '{0}'", libraryVariableSetName));
}

// Get the variable set
var variableSet = repository.VariableSets.Get(librarySet.VariableSetId);

// Update the variable
variableSet.Variables.FirstOrDefault(v => v.Name == variableName).Value = variableValue;
repositoryForSpace.VariableSets.Modify(variableSet);