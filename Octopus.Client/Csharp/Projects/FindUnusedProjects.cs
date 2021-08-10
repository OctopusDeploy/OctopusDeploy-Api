// If using .net Core, be sure to add the NuGet package of System.Security.Permissions
#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

var octopusURL = "https://your.octopus.app";
var octopusAPIKey = "API-YOURKEY";
DateTime currentUtcTime = DateTime.Now.ToUniversalTime();
System.Collections.Generic.List<string> oldProjects = new System.Collections.Generic.List<string>();
int daysSinceLastRelease = 90;

// Create repository object
var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);

// Loop through all spaces
foreach (var octopusSpace in repository.Spaces.FindAll())
{
    // Get space repository
    var space = repository.Spaces.FindByName(octopusSpace.Name);
    var repositoryForSpace = client.ForSpace(space);

    // Get all projects
    var projects = repositoryForSpace.Projects.GetAll();

    // Loop through projects
    foreach (var project in projects)
    {
        if(project.IsDisabled)
        {
            Console.WriteLine(string.Format("{0} is disabled", project.Name));
            continue;
        }

        // Get releases for project
        var releases = repositoryForSpace.Projects.GetAllReleases(project);

        // Check to see if anything has ever been created
        if (releases.Count == 0)
        {
            Console.WriteLine(string.Format("No releases found for {0}", project.Name));
            continue;
        }

        var assembledDate = releases[0].Assembled.ToUniversalTime();
        var dateDiff = currentUtcTime - assembledDate;

        // Check to see how many days it has been 
        if (dateDiff.TotalDays > daysSinceLastRelease)
        {
            oldProjects.Add(string.Format("{0} - {1} last release was {2} days ago.", project.Name, space.Name, dateDiff.TotalDays.ToString()));
        }
    }
}

Console.WriteLine(string.Format("The following projects were found to have no releases created in at least {0} days", daysSinceLastRelease));
foreach(var project in oldProjects)
{
    Console.WriteLine(string.Format("\t {0}", project));
}