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

            var endpoint = new OctopusServerEndpoint(octopusURL, apiKey);
            var client = new OctopusClient(endpoint);
            var repository = new OctopusRepository(endpoint);

            var actionTemplates = repository.ActionTemplates.GetAll();
            foreach (var actionTemplate in actionTemplates)
            {
                var usages = client.Get<ActionTemplateUsageResource[]>(actionTemplate.Links["Usage"]);
                var usagesToUpdate = usages.Where(u => u.Version != actionTemplate.Version.ToString());

                if (!usagesToUpdate.Any()) continue;

                var actionsByProcessId = usagesToUpdate.GroupBy(u => u.DeploymentProcessId);
                var actionIdsByProcessId = actionsByProcessId.ToDictionary(g => g.Key, g => g.Select(u => u.ActionId).ToArray());

                var actionUpdate = new ActionsUpdateResource();
                actionUpdate.Version = actionTemplate.Version;
                actionUpdate.ActionIdsByProcessId = actionIdsByProcessId;
                repository.ActionTemplates.UpdateActions(actionTemplate, actionUpdate);
            }
        }
    }
}