void Main()
{
    OctopusServerEndpoint endpoint = new OctopusServerEndpoint("http://localhost", "API-XXXXXXXXXXXXXXXXXX");
    var repository = new OctopusRepository(endpoint);

    var project = repository.Projects.FindByName("Test");
    var tasks = repository.Tasks.GetAllActive();
    foreach (var task in tasks)
    {
        if (task.Name == "Deploy" &&
             task.StartTime.HasValue &&
             task.State == TaskState.Executing
        )
        {
            var deploymentId = (string)task.Arguments["DeploymentId"];
            var deployment = repository.Deployments.Get(deploymentId);

            if (deployment.ProjectId == project.Id && ShouldCancel(repository, task, deployment))
                repository.Tasks.Cancel(task);
        }
    }
}

bool ShouldCancel(OctopusRepository repository, TaskResource task, DeploymentResource deployment)
{
    var runTime = (DateTimeOffset.Now - task.StartTime.Value);
    if (runTime > TimeSpan.FromMinutes(30))
        return true;

    var step1 = repository.Tasks.GetDetails(task).ActivityLogs
        .SelectMany(l => l.Children)
        .FirstOrDefault(l => l.Name.StartsWith("Step 1"));

    if (step1?.Status != ActivityStatus.Running)
        return false; // Either not started, or completed

    var startTime = step1.Children.FirstOrDefault()?.LogElements.FirstOrDefault().OccurredAt;
    var lastLog = step1.Children.SelectMany(c => c.LogElements).Max(e => e.OccurredAt);
    var stepRunTime = lastLog - startTime;
    var sinceLastLog = DateTimeOffset.Now - lastLog;

    if (stepRunTime.HasValue && stepRunTime.Value > TimeSpan.FromMinutes(20))
        return true; // Cancel if step 1 has been running for 20 minutes

    if (sinceLastLog.HasValue && sinceLastLog.Value > TimeSpan.FromMinutes(5))
        return true;// Cancel if no logs recieved on step 1 for 5 minutes

    return false;
}
