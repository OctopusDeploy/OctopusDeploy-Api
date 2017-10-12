<Query Kind="Statements">
  <Reference Relative="..\..\..\OctopusDeploy\source\Octopus.Client\bin\Octopus.Client.dll">C:\Code\GitHub\OctopusDeploy\source\Octopus.Client\bin\Octopus.Client.dll</Reference>
</Query>

var endpoint = new Octopus.Client.OctopusServerEndpoint("http://octopus.url", "API-XXXXXXXXXXXXXXXXXXXXXXXXXX");
var client = new Octopus.Client.OctopusClient(endpoint);
var repo = new Octopus.Client.OctopusRepository(client);

var dynamicDashboardUri = client.RootDocument.Link("DashboardDynamic");

var project = repo.Projects.FindByName("ProjectName");
var environment = repo.Environments.FindByName("EnvironmentName");

var dashboard = client.Get<Octopus.Client.Model.DashboardResource>(dynamicDashboardUri, new { projects = project.Id, environments = environment.Id, includePrevious = true});
Octopus.Client.Model.DashboardItemResource lastSuccessful;
if(dashboard.Items[0].State == Octopus.Client.Model.TaskState.Success)
{
	lastSuccessful = dashboard.Items[0];
}
else
{
	lastSuccessful = dashboard.PreviousItems.FirstOrDefault (pi => pi.State == Octopus.Client.Model.TaskState.Success);
}
var task = repo.Tasks.Get(lastSuccessful.TaskId);
var taskDetail = repo.Tasks.GetDetails(task);
var machines = taskDetail.ActivityLogs.First().Children.First(c => c.Name.Equals("Acquire packages", StringComparison.OrdinalIgnoreCase)).Children.Select(c => c.Name);
machines.Dump();
