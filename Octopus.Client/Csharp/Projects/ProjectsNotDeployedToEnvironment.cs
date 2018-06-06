// Prints the names of the projects for which the latest release has not been successfully deployed 
// to a given environment. 

var client = new OctopusClient(new OctopusServerEndpoint(octoUrl, apiKey));
var repository = new OctopusRepository(client);

var environmentName = "Production";
var environment = repository.Environments.FindByName(environmentName);

foreach (var project in repository.Projects.GetAll())
{
    var latestRelease = repository.Projects.GetReleases(project, take: 1).Items.SingleOrDefault();
    var lifecycle = repository.Lifecycles.Get(project.LifecycleId);

    // Exclude projects which have no releases or where the lifecycle does not contain the requested environment
    if (latestRelease == null 
        || !lifecycle.Phases.SelectMany(phase => phase.AutomaticDeploymentTargets.Union(phase.OptionalDeploymentTargets)).Contains(environment.Id))
    {
        continue;
    }
    
    var progression = repository.Projects.GetProgression(project);
    var releaseProgression = progression.Releases.Single(r => r.Release.Id == latestRelease.Id);

    if (!releaseProgression.Deployments.TryGetValue(environment.Id, out var environmentDeployments) || 
        !environmentDeployments.Any(d => d.State == TaskState.Success))
    {
        Console.WriteLine(project.Name);
    }
