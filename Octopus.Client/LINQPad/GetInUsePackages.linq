<Query Kind="Statements">
  <NuGetReference>Octopus.Client</NuGetReference>
  <Namespace>Octopus.Client</Namespace>
  <Namespace>Octopus.Client.Model</Namespace>
</Query>


var endpoint = new OctopusServerEndpoint("http://localhost");
var repository = new OctopusRepository(endpoint);
repository.Users.SignIn("user", "password");

var releases = repository.Releases.FindAll(); // This call can slow the server down

var processes = new Dictionary<string, DeploymentProcessResource>();
foreach(var id in releases.Select(r => r.ProjectDeploymentProcessSnapshotId).Distinct()) // This can take a long time
 	processes[id] = repository.DeploymentProcesses.Get(id);

var inUsePackagesQ = from release in releases
					from selectedPackage in release.SelectedPackages
					select new
					{
						PackageId = processes[release.ProjectDeploymentProcessSnapshotId]
										.Steps
										.SelectMany(s => s.Actions)
										.First(s => s.Name == selectedPackage.StepName)
										.Properties["Octopus.Action.Package.PackageId"].Value,
						Version = selectedPackage.Version
					};
var inUsePackages = inUsePackagesQ.Distinct().ToArray();
inUsePackages.Dump();
