<Query Kind="Statements">
  <NuGetReference>Octopus.Client</NuGetReference>
</Query>

var octopusUrl = "http://octopus.url";
var apiKey = "API-XXXXXXXXXXXXXXXXXXXXXXXXXX";

var octopusServer = new Octopus.Client.OctopusServerEndpoint(octopusUrl, apiKey);
var repo = new Octopus.Client.OctopusRepository(octopusServer);

var newLibraryVariableSet = new Octopus.Client.Model.LibraryVariableSetResource();
newLibraryVariableSet.Name = "Name";
newLibraryVariableSet.Description = "Description";
var skipDeltaCompressionVariableSet = repo.LibraryVariableSets.Create(newLibraryVariableSet);

var newVariableSet = repo.VariableSets.Get(skipDeltaCompressionVariableSet.VariableSetId);
newVariableSet.Variables.Add(new Octopus.Client.Model.VariableResource { Name = "Variable Name", Value = "value" });

var variableSet = repo.VariableSets.Modify(newVariableSet);

var projects = repo.Projects.GetAll();
foreach(var projectRef in projects)
{
	var project = repo.Projects.Get(projectRef.Id);
	project.IncludedLibraryVariableSetIds.Add(skipDeltaCompressionVariableSet.Id);
	repo.Projects.Modify(project);
}