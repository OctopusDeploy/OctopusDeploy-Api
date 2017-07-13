<Query Kind="Statements">
  <NuGetReference>Newtonsoft.Json</NuGetReference>
  <NuGetReference>Octopus.Client</NuGetReference>
  <Namespace>Octopus.Client</Namespace>
  <Namespace>Octopus.Client.Model</Namespace>
  <Namespace>Octopus.Client.Model.Endpoints</Namespace>
  <Namespace>Octopus.Client.Serialization</Namespace>
  <Namespace>System.Net</Namespace>
  <Namespace>System.Net.Http</Namespace>
  <Namespace>Newtonsoft.Json</Namespace>
</Query>

// This script shows how to retrieve, export, import, manipulate and update a project's variables

var endpoint = new OctopusServerEndpoint("http://localhost", "API-AOLL7T3QASOZEJROIAYAGBWA6M");
var repository = new OctopusRepository(endpoint);


var project = repository.Projects.FindByName("Test");
var set = repository.VariableSets.Get(project.VariableSetId);

// Export to a CSV file
File.WriteAllText(@"C:\temp\vars.json", JsonConvert.SerializeObject(set, Newtonsoft.Json.Formatting.Indented));

// Time passes

// Import it again
set = JsonConvert.DeserializeObject<VariableSetResource>(File.ReadAllText(@"C:\temp\vars.json"));
var currentSet = repository.VariableSets.Get(project.VariableSetId);
set.Id = currentSet.Id; // Required if you are importing from a different project
set.OwnerId = currentSet.OwnerId; // Required if you are importing from a different project
set.Version = currentSet.Version; // Required if you want to update regardless of whether they have changed since export
set.Links = currentSet.Links; // Fixed up the links collection

// Add an environment to the Scope of a variable
var variable = set.Variables.First(v => v.Name == "Scoped");
var environmentId = set.ScopeValues.Environments.First(r => r.Name == "Local").Id;

ScopeValue envScope;
if (variable.Scope.TryGetValue(ScopeField.Environment, out envScope))
{
	envScope.Add(environmentId);
}
else
{
	envScope = new ScopeValue(environmentId);
	variable.Scope[ScopeField.Environment] = envScope;
}

variable.Scope[ScopeField.Environment] = envScope;

// Update the variable
repository.VariableSets.Modify(set);
