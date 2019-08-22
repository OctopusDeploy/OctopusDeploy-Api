<Query Kind="Statements">
  <Reference>&lt;RuntimeDirectory&gt;\System.IO.Compression.FileSystem.dll</Reference>
  <Reference>&lt;RuntimeDirectory&gt;\System.IO.Compression.dll</Reference>
  <NuGetReference>Octopus.Client</NuGetReference>
  <Namespace>Octopus.Client</Namespace>
  <Namespace>Octopus.Client.Model</Namespace>
  <Namespace>Octopus.Client.Model.Endpoints</Namespace>
  <Namespace>Octopus.Client.Serialization</Namespace>
  <Namespace>System.Net.Http</Namespace>
  <Namespace>System.IO.Compression</Namespace>
  <Namespace>Octopus.Client.Model.Triggers</Namespace>
  <Namespace>Newtonsoft.Json</Namespace>
</Query>

var environmentName = "Production";
var projectName = "MyProject";
var releaseVersion = "0.0.13";
var outputFolder = @"c:\temp\logfiles";

var serverUrl = "http://localhost";

var creds = (user: "Admin", pass: "password");
string apiKey = null;
// OR:
// var creds = (user:null, pass:null);
// string apiKey = "API-";


if(!Directory.Exists(outputFolder))
	Directory.CreateDirectory(outputFolder);

var repository =  new OctopusRepository(new OctopusServerEndpoint("http://localhost", apiKey));
if(creds.user != null)
	repository.Users.SignIn(creds.user, creds.pass);

var production = repository.Environments.FindByName(environmentName);
var tenants = repository.Tenants.GetAll().ToDictionary(t => t.Id);
var project = repository.Projects.FindByName(projectName);
var release = repository.Projects.GetReleaseByVersion(project, releaseVersion);

var deployments = repository.Releases.GetDeployments(release, take: int.MaxValue);

deployments
	.Items
	.Where(d => d.EnvironmentId == production.Id)
	.AsParallel()
	.WithDegreeOfParallelism(5)
	.ForAll(d =>
	{
		var tenant = d.TenantId == null ? null : tenants[d.TenantId];
		var task = repository.Tasks.Get(d.TaskId);
		var details = repository.Tasks.GetDetails(task, includeVerboseOutput: true, tail: null);
		var json = JsonConvert.SerializeObject(details, Newtonsoft.Json.Formatting.Indented);
		var filename = Path.Combine(outputFolder, $"{task.Id} - {tenant?.Name}.json");
		File.WriteAllText(filename, json);
	});
		
