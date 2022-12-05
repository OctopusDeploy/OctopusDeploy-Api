// If using .net Core, be sure to add the NuGet package of System.Security.Permissions

// Reference Octopus.Client
#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

public class DeploymentDetails
{
	public string ReleaseVersion { get; set; }
	public string StepName { get; set; }
	public string PackageId { get; set; }
	public string PackageVersion { get; set; }
	public string MachineName { get; set; }
	public string FolderPath { get; set; }
}


var sw = Stopwatch.StartNew();

// Working variables
string octopusURL = "https://your.octopus.app";
string octopusAPIKey = "API-KEY";
string spaceName = "Default";
bool verboseOutput = false;
int deploymentsToTake = 2;

// Project name
string projectName = "Your Project Name";

// Environment Name
string environmentName = "Development";

// variable name matcher
var packageVariableMatcher = new Regex(@"^Octopus\.Action\[(?<stepName>.*)\]\.Output\[(?<machineName>.*)\]\.Octopus\.Action\.Package\.InstallationDirectoryPath$", RegexOptions.Compiled);

// Create repository objects
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

try
{
    // Get space
    var space = repository.Spaces.FindByName(spaceName);
    var repositoryForSpace = client.ForSpace(space);

    EnvironmentResource environment = null;
    ProjectResource project = null;

    // Get project
    if (string.IsNullOrWhiteSpace(projectName))
    {
        throw new ArgumentNullException("projectName");
    }
    else
    {
        if (verboseOutput)
            Console.WriteLine($"INFO: Getting project: {projectName}");

        project = repositoryForSpace.Projects.FindByName(projectName);
    }

    // Get environment
    if (string.IsNullOrWhiteSpace(environmentName))
    {
        throw new ArgumentNullException("environmentName");
    }
    else
    {
        if (verboseOutput)
            Console.WriteLine($"INFO: Getting environment: {environmentName}");

        environment = repositoryForSpace.Environments.FindByName(environmentName);
    }

    Console.WriteLine($"INFO: Working on project '{project.Name}'.");

    // Get a projects "progression" for the deployments to each environment.
    var progression = repositoryForSpace.Projects.GetProgression(project);

    // Get deployments environment to validate that this environment is applicable to the project.
    var deploymentEnvironment = progression.Environments.FirstOrDefault(e => e.Id == environment.Id);
    if (deploymentEnvironment == null)
    {
        throw new ArgumentNullException("deploymentEnvironment");
    }

    // Get the last X successful deployments
    var deploymentListResults = client.List<DeploymentResource>(repositoryForSpace.Link("Deployments"), new { skip = 0, take = deploymentsToTake, projects = project.Id, environments = deploymentEnvironment.Id, taskState = "Success" });
    var deployments = deploymentListResults.Items;

    List<DeploymentDetails> results = new List<DeploymentDetails>();

    if (deployments.Count < 1)
    {
        Console.WriteLine($"WARNING: no successful deployments found for environment '{environment.Name}'.");
        return;
    }
    else
    {
        foreach (var d in deployments)
        {
            var release = repositoryForSpace.Releases.Get(d.ReleaseId);
            if (verboseOutput)
                Console.WriteLine($"INFO: Working on release '{release.Version}' ({release.Id}).");

            var variableSet = repositoryForSpace.VariableSets.Get(d.ManifestVariableSetId);
            var foundPackages = false;
            foreach (var variable in variableSet.Variables)
            {
                var variableName = variable.Name;
                Match match = packageVariableMatcher.Match(variableName);
                if (match.Success)
                {
                    foundPackages = true;
                    if (verboseOutput)
                        Console.WriteLine($"INFO: found matching variable named '{variableName}'.");

                    var groups = match.Groups;

                    // Regex supplied values
                    var stepName = match.Groups["stepName"].Value;
                    var machineName = match.Groups["machineName"].Value;

                    var variableValue = variable.Value;
                    var fullPath = variableValue;
                    var subPaths = fullPath.Split(Path.DirectorySeparatorChar);

                    // PackageId
                    var packageId = subPaths[subPaths.Length - 2];
                    // Package version
                    var pathPackageVersion = subPaths.Last();
                    var packageVersion = pathPackageVersion.Split('_').First();

                    var result = new DeploymentDetails
                    {
                        ReleaseVersion = release.Version,
                        StepName = stepName,
                        PackageId = packageId,
                        PackageVersion = packageVersion,
                        MachineName = machineName,
                        FolderPath = fullPath
                    };
                    results.Add(result);
                }
            }
            if (!foundPackages)
            {
                Console.WriteLine($"WARNING: no variables found for package install path for release '{release.Version}'.");
            }
        }
    }

    foreach (var r in results)
    {
        Console.WriteLine("{0} deployed package {1} ({2}) to machine: {3} ({4})", r.ReleaseVersion, r.PackageId, r.PackageVersion, r.MachineName, r.FolderPath);
    }
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}
finally
{
    sw.Stop();
    Console.WriteLine($"Elapsed time: {sw.Elapsed}");
}