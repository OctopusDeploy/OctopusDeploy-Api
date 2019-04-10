<Query Kind="Statements">
  <NuGetReference>Octopus.Client</NuGetReference>
  <Namespace>Octopus.Client</Namespace>
  <Namespace>Octopus.Client.Model</Namespace>
</Query>

// This will print out all packages that are currently referenced by a release
// Output: Feed Name, Package Id, Package Version

var endpoint = new OctopusServerEndpoint("http://localhost");
var repository = new OctopusRepository(endpoint);
repository.Users.SignIn("Admin", "password");

var feeds = repository.Feeds.FindAll().ToDictionary(f => f.Id, f => f.Name);

var releases = repository.Releases.FindAll(); // This call can slow the server down

var processes = new Dictionary<string, DeploymentProcessResource>();
foreach(var id in releases.Select(r => r.ProjectDeploymentProcessSnapshotId).Distinct()) // This can take a long time
 	processes[id] = repository.DeploymentProcesses.Get(id);

var inUsePackagesQ = from release in releases
					 from selectedPackage in release.SelectedPackages
					 let action = processes[release.ProjectDeploymentProcessSnapshotId]
										 .Steps
										 .SelectMany(s => s.Actions)
										 .First(s => s.Name == selectedPackage.ActionName)
					 select new
					{
						Feed = feeds[action.Properties["Octopus.Action.Package.FeedId"].Value],
						PackageId = action.Properties["Octopus.Action.Package.PackageId"].Value,
						Version = selectedPackage.Version
					};
var inUsePackages = inUsePackagesQ.Distinct().ToArray();
inUsePackages.Dump();


