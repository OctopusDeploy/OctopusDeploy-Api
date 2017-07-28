<Query Kind="Program">
  <NuGetReference>Octopus.Client</NuGetReference>
  <Namespace>Octopus.Client</Namespace>
  <Namespace>Octopus.Client.Model</Namespace>
</Query>

void Main()
{
	var sourceProjectName = "<Source project name>";
	var targetProjectName = "<Target project name>";
	var stepToCopyName = "<name of the source step to copy>";

	var repo = GetOctopusRepository();
	var sourceProject = repo.Projects.FindByName(sourceProjectName);
	var targetProject = repo.Projects.FindByName(targetProjectName);

	if (sourceProject != null && targetProject != null)
	{
		var sourceDeploymentProcess = repo.DeploymentProcesses.Get(sourceProject.DeploymentProcessId);
		var targetDeploymentProcess = repo.DeploymentProcesses.Get(targetProject.DeploymentProcessId);

		if (sourceDeploymentProcess != null && targetDeploymentProcess != null)
		{
			Console.WriteLine($"Start copy from project '{sourceProjectName}' to project '{targetProjectName}'");

			CopyStepToTarget(sourceDeploymentProcess, targetDeploymentProcess, stepToCopyName);

			// Update or add the target deployment process
			repo.DeploymentProcesses.Modify(targetDeploymentProcess);

			Console.WriteLine($"End copy from project '{sourceProjectName}' to project '{targetProjectName}'");
		}
	}
}

private OctopusRepository GetOctopusRepository()
{
	var octopusServer = "https://<your server address>";
	var octopusApiKey = "API-AAAAAAAAAAAAAAAAAAAAAAAAA";
	var endPoint = new OctopusServerEndpoint(octopusServer, octopusApiKey);

	return new OctopusRepository(endPoint);
}

private void CopyStepToTarget(DeploymentProcessResource sourceProcess, DeploymentProcessResource targetProcess, string sourceStepName, bool includeChannels = false, bool includeEnvironments = false)
{
	var sourceStep = sourceProcess.FindStep(sourceStepName);

	if (sourceStep == null)
	{
		Console.WriteLine($"{sourceStepName} not found in {sourceProcess.ProjectId}");
		return;
	}

	Console.WriteLine($"-> copy step '{sourceStep.Name}'");

	var stepToAdd = targetProcess.AddOrUpdateStep(sourceStep.Name);
	stepToAdd.RequirePackagesToBeAcquired(sourceStep.RequiresPackagesToBeAcquired);
	stepToAdd.WithCondition(sourceStep.Condition);
	stepToAdd.WithStartTrigger(sourceStep.StartTrigger);

	foreach (var property in sourceStep.Properties)
	{
		if (stepToAdd.Properties.ContainsKey(property.Key))
		{
			stepToAdd.Properties[property.Key] = property.Value;
		}
		else
		{
			stepToAdd.Properties.Add(property.Key, property.Value);
		}
	}

	foreach (var sourceAction in sourceStep.Actions)
	{
		Console.WriteLine($"-> copy action '{sourceAction.Name}'");

		var targetAction = stepToAdd.AddOrUpdateAction(sourceAction.Name);
		targetAction.ActionType = sourceAction.ActionType;
		targetAction.IsDisabled = sourceAction.IsDisabled;

		if (includeChannels)
		{
			foreach (var sourceChannel in sourceAction.Channels)
			{
				targetAction.Channels.Add(sourceChannel);
			}
		}

		if (includeEnvironments)
		{
			foreach (var sourceEnvironment in sourceAction.Environments)
			{
				targetAction.Environments.Add(sourceEnvironment);
			}
		}

		foreach (var actionProperty in sourceAction.Properties)
		{
			if (targetAction.Properties.ContainsKey(actionProperty.Key))
			{
				targetAction.Properties[actionProperty.Key] = actionProperty.Value;
			}
			else
			{
				targetAction.Properties.Add(actionProperty.Key, actionProperty.Value);
			}
		}
	}
}
