# You can get this dll from NuGet
# https://www.nuget.org/packages/Octopus.Client/
# Load Octopous Client assembly
Add-Type -Path 'c:\octopus.client\Octopus.Client.dll' 

# Declare Octopus variables
$apikey = 'API-YOURAPIKEY' 
$octopusURI = 'https://youroctourl'
$projectName = "MyProject"

# Create repository object
$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = New-Object Octopus.Client.OctopusRepository $endpoint
$client = New-Object Octopus.Client.OctopusClient($endpoint)

# Get reference to space
$space = $repository.Spaces.FindByName($spaceName)
$repositoryForSpace = $client.ForSpace($space)

try
{
    # Get project
    $project = $repositoryForSpace.Projects.FindByName($projectName)

    # Get project process
    $process = $repositoryForSpace.DeploymentProcesses.Get($project.DeploymentProcessId)

    # Define new step
    $stepName = "Run a script" # The name of the step
    $role = "My role" # The machine role to run this step on
    $scriptBody = "Write-Host 'Hello world'" # The script to run
    $step = New-Object Octopus.Client.Model.DeploymentStepResource
    $step.Name = $stepName
    $step.Condition = [Octopus.Client.Model.DeploymentStepCondition]::Success
    $step.Properties.Add("Octopus.Action.TargetRoles", $role)

    # Define script action
    $scriptAction = New-Object Octopus.Client.Model.DeploymentActionResource
    $scriptAction.ActionType = "Octopus.Script"
    $scriptAction.Name = $stepName
    $scriptAction.Properties.Add("Octopus.Action.Script.ScriptBody", $scriptBody)

    # Add step to process
    $step.Actions.Add($scriptAction)
    $process.Steps.Add($step)
    $repositoryForSpace.DeploymentProcesses.Modify($process)
}
catch
{
    # Display error
    Write-Host $_.Exception.Message
}