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
            var apiKey = "API-B3ZK7BTFAKSKRTCHQFKAZNPT5Y";
            var octopusURL = "http://localhost:82";
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

            foreach (var packages in template.Packages)
            {
                var selectedPackage = new SelectedPackage();
                selectedPackage.StepName = packages.StepName;

                //If you don't pass a value to FixedPackageVersion, select the latest in the feed that matches version rules.
                if (string.IsNullOrEmpty(fixedPackageVersion))
                {
                    var filters = new Dictionary<string, object>();
                    var feed = repository.Feeds.Get(packages.FeedId);
                    var rule = channel.Rules.FirstOrDefault(r => r.Actions.Contains(selectedPackage.StepName));
                    if (rule != null)
                    {
                        if (!string.IsNullOrWhiteSpace(rule.VersionRange))
                            filters["versionRange"] = rule.VersionRange;

                        if (!string.IsNullOrWhiteSpace(rule.Tag))
                            filters["preReleaseTag"] = rule.Tag;
                    }

                    filters["packageId"] = packages.PackageId;
                    var packagelist = repository.Client.Get<List<PackageResource>>(feed.Link("SearchTemplate"), filters);
                    var latestPackage = packagelist.FirstOrDefault();

                    selectedPackage.Version = latestPackage.Version;
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