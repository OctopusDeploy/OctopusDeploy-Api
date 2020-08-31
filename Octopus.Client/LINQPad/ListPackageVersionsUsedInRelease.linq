<Query Kind="Program">
  <NuGetReference>Octopus.Client</NuGetReference>
  <Namespace>Octopus.Client</Namespace>
  <Namespace>Octopus.Client.Exceptions</Namespace>
  <Namespace>Octopus.Client.Extensions</Namespace>
  <Namespace>Octopus.Client.Model</Namespace>
  <Namespace>Octopus.Client.Model.Accounts</Namespace>
  <Namespace>Octopus.Client.Model.Endpoints</Namespace>
  <Namespace>Octopus.Client.Model.Forms</Namespace>
  <Namespace>Octopus.Client.Operations</Namespace>
  <Namespace>Octopus.Client.Repositories</Namespace>
  <Namespace>Octopus.Client.Serialization</Namespace>
  <Namespace>Octopus.Client.Validation</Namespace>
</Query>

void Main()
{
	const string packageIdPropertyKey = "Octopus.Action.Package.NuGetPackageId";

	string octopusUrl = "https://octopus.url";
	string apiKey = "API-XXXXXXXXXXXXXXXXXXXX";
	string projectName = "myprojectname";

	var octopusServer = new OctopusServerEndpoint(octopusUrl, apiKey);
	var repo = new OctopusRepository(octopusServer);

	var project = repo.Projects.FindByName(projectName);
	var allReleases = repo.Releases.FindAll();
	foreach (var release in allReleases)
	{
		// Get the snapshot of the deployment process for this release
		var deploymentProcessSnapshot = repo.Client.Get<DeploymentProcessResource>(release.Link("ProjectDeploymentProcessSnapshot")).Dump();

		// Get the list of Steps and the PackageId for each step
		// NOTE: This will not work as expected if you are using #{} variable expressions for the PackageId
		var stepsAndPackageIds = deploymentProcessSnapshot.Steps
			.Where(s => s.Actions.Any(a => a.Properties.ContainsKey(packageIdPropertyKey)))
			.Select(s => new { StepName = s.Name, PackageId = s.Actions.Single(a => a.Properties.ContainsKey(packageIdPropertyKey)).Properties[packageIdPropertyKey] })
			.OrderBy(x => x.StepName).ToArray();

		// List the Packages and their versions for this release
		Console.WriteLine("OctoFX " + release.Version);
		foreach (var step in stepsAndPackageIds)
		{
			Console.WriteLine("- {0}: {1} {2}", step.StepName, step.PackageId, release.SelectedPackages.Single(sp => sp.StepName == step.StepName).Version);
		}
	}
}
