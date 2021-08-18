$ErrorActionPreference = "Stop";

# Load assembly
Add-Type -Path 'path:\to\Octopus.Client.dll'
# Define working variables
$octopusURL = "https://YourURL"
$octopusAPIKey = "API-YourAPIKey"
$spaceName = "Default"
$sourceEnvironmentName = "Production"
$destinationEnvironmentName = "Test"
$projectNameList = @("MyProject")
 

# Establish a conneciton0
$endpoint = New-Object Octopus.Client.OctopusServerEndpoint($octopusURL, $octopusAPIKey)
$repository = New-Object Octopus.Client.OctopusRepository($endpoint)
$client = New-Object Octopus.Client.OctopusClient($endpoint)

# Get repository specific to space
$space = $repository.Spaces.FindByName($spaceName)
$repositoryForSpace = $client.ForSpace($space)

# Get the source environment
$sourceEnvironment = $repositoryForSpace.Environments.FindByName($sourceEnvironmentName)

# Get the destination environment
$destinationEnvironment = $repositoryForSpace.Environments.FindByName($destinationEnvironmentName)

# Loop through the projects
foreach ($name in $projectNameList)
{
    # Get project object
    $project = $repositoryForSpace.Projects.FindByName($name)

    Write-Host "The project Id for project name $name is $($project.Id)"
    Write-Host "I have all the Ids I need, I am going to find the most recent sucesseful deployment now to $sourceEnvironmentName"

    # Get the deployment tasks associated with this space, project, and environment
    $taskList = $repositoryForSpace.Deployments.FindBy(@($project.Id), @($sourceEnvironment.Id), 0, $null).Items | Where-Object {$repositoryForSpace.Tasks.Get($_.TaskId).State -eq [Octopus.Client.Model.TaskState]::Success}
    
    # Check to see if any tasks were returned
    if ($taskList.Count -eq 0)
    {
        Write-Host "Unable to find a successful deployment for project $($project.Name) to $($sourceEnvironment.Name)"
        continue
    }

    # Grab the last successful deployment
    $lastDeploymentTask = $taskList[0]

    Write-Host "The id of the last deployment for $($project.Name) to $($sourceEnvironment.Name) is $($lastDeploymentTask.Id)"

    # Get the deployment object
    Write-Host "The release id for $deploymentId is $($lastDeploymentTask.ReleaseId)"

    $canPromote = $false

    Write-Host "I have all the Ids I need, I am going to find the most recent successful deployment to $($destinationEnvironment.Name)"

    # Get the task list for the destination environment
    $destinationTaskList = $repositoryForSpace.Deployments.FindBy(@($project.Id), @($destinationEnvironment.Id), 0, $null).Items | Where-Object {$repositoryForSpace.Tasks.Get($_.TaskId).State -eq [Octopus.Client.Model.TaskState]::Success}
    
    if ($destinationTaskList.Count -eq 0)
    {
        Write-Host "The destination has no releases, promoting."
        $canPromote = $true
    }

    # Get the last destination deployment
    $lastDestinationDeploymentTask = $destinationTaskList[0]

    Write-Host "The deployment id of the last deployment for $($project.Name) to $($destinationEnvironment.Name) is $($lastDestinationDeploymentTask.Id)"
    Write-Host "The release id of the last deployment to the destination is $($lastDestinationDeploymentTask.ReleaseId)"

    if ($lastDestinationDeploymentTask.ReleaseId -ne $lastDeploymentTask.ReleaseId)
    {
        Write-Host "The releases on teh source and destination don't match, promoting"
        $canPromote = $true
    }
    else
    {
        Write-Host "The releases match, not promoting"
    }

    if ($canPromote -eq $false)
    {
        Write-Host "Nothing to promote for $($project.Name)"
        continue
    }

    # Create new deployment object
    $deployment = New-Object Octopus.Client.Model.DeploymentResource
    $deployment.EnvironmentId = $destinationEnvironment.Id
    $deployment.ReleaseId = $lastDeploymentTask.ReleaseId

    # Execute the deployment
    $repositoryForSpace.Deployments.Create($deployment)
}