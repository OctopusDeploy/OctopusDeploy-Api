using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Octopus.Client;
using Octopus.Client.Model;

namespace OctopusClient_Test
{
    class Program
    {
        static void Main(string[] args)
        {
            var apiKey = "API-XXXXXXXXXXXXXXXXXXXXXXXXXX";
            var octopusURL = "https://octopus.url";
            var projectName = "testproject2";
            var releaseVersion = "";
            var channelName = "Default";
            var environmentName = "Dev";
            var fixedPackageVersion = "";

            var endpoint = new OctopusServerEndpoint(octopusURL, apiKey);
            var repository = new OctopusRepository(endpoint);

            var project = repository.Projects.FindByName(projectName);
            var environment = repository.Environments.FindByName(environmentName);

            var template = new ReleaseTemplateResource();
            var process = new DeploymentProcessResource();

            process = repository.DeploymentProcesses.Get(project.DeploymentProcessId);
            var channel = repository.Channels.FindByName(project, channelName);
            template = repository.DeploymentProcesses.GetTemplate(process,channel);

            //if you dont pass a value to newReleaseVersion, It'll calculate it using the version template of your project. Just like when you hit the "Create Release" button from the web portal
            if (string.IsNullOrEmpty(releaseVersion))
            {
                releaseVersion = template.NextVersionIncrement;
            }

            //Creating the release object
            var newrelease = new ReleaseResource
            {
                ProjectId = project.Id,
                Version = releaseVersion
            };

            foreach (var package in template.Packages)
            {
                var selectedPackage = new SelectedPackage
                {
                    ActionName = package.ActionName,
                    PackageReferenceName = package.PackageReferenceName
                };

                //If you don't pass a value to FixedPackageVersion, Octopus will look for the latest one in the feed.
                if (string.IsNullOrEmpty(fixedPackageVersion))
                {
                    //Gettin the latest version of the package available in the feed.
                    //This is probably the most complicated line. The expression can get tricky, as a step(action) might be a parent and have many children(more nested actions)
                    var packageStep =
                        process.Steps.FirstOrDefault(s => s.Actions.Any(a => a.Name == selectedPackage.ActionName))?
                            .Actions.FirstOrDefault(a => a.Name == selectedPackage.ActionName);

                    var packageId = packageStep.Properties["Octopus.Action.Package.PackageId"].Value;
                    var feedId = packageStep.Properties["Octopus.Action.Package.FeedId"].Value;

                    var feed = repository.Feeds.Get(feedId);

                    var latestPackageVersion = repository.Feeds.GetVersions(feed, new[] { packageId }).FirstOrDefault();

                    selectedPackage.Version = latestPackageVersion.Version;
                }
                else
                {
                    selectedPackage.Version = fixedPackageVersion;
                }

                newrelease.SelectedPackages.Add(selectedPackage);
            }

            //Creating the release in Octopus
            var release = repository.Releases.Create(newrelease);

            //creating the deployment object
            var deployment = new DeploymentResource
            {
                ReleaseId = release.Id,
                ProjectId = project.Id,
                EnvironmentId = environment.Id
            };

            //Deploying the release in Octopus
            repository.Deployments.Create(deployment);

        }
    }
}