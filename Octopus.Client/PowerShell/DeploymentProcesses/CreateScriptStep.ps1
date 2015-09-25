# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll' 

$apikey = 'API-MCPLE1AQM2VKTRFDLIBMORQHBXA' # Get this from your profile
$octopusURI = 'http://localhost' # Your server address

$projectId = "Projects-100" # Get this from /api/projects
$stepName = "Run a script" # The name of the step
$role = "demo-role" # The machine role to run this step on
$scriptBody = "Write-Host 'Hello world'" # The script to run

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

$project = $repository.Projects.Get($projectId)
$process = $repository.DeploymentProcesses.Get($project.DeploymentProcessId)

$step = New-Object Octopus.Client.Model.DeploymentStepResource
$step.Name = $stepName
$step.Condition = [Octopus.Client.Model.DeploymentStepCondition]::Success
$step.Properties.Add("Octopus.Action.TargetRoles", $role)

$scriptAction = New-Object Octopus.Client.Model.DeploymentActionResource
$scriptAction.ActionType = "Octopus.Script"
$scriptAction.Name = $stepName
$scriptAction.Properties.Add("Octopus.Action.Script.ScriptBody", $scriptBody)

$step.Actions.Add($scriptAction)

$process.Steps.Add($step)

$repository.DeploymentProcesses.Modify($process)
