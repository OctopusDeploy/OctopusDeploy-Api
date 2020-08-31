Add-Type -Path 'Octopus.Client.dll'

$apikey = 'API-XXXXXXXXXXXXXXXXXXXXXX' # Get this from your profile
$octopusURI = 'https://octopus.url' # Your server address

$stepName = "API-ADDED-STEP" # The name of the step to be created
$role = "Webserver" # The machine role to run this step against
$scriptBody = "Write-Host 'Hello world'" # The body of the script step

## Uncomment the below line (And the other two) to scope the step to an Environment ##
#$environment = "Dev" #  The name of the Environment to scope step to

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

$allProjects = $repository.Projects.GetAll()

## Uncomment the below line to scope the step to an Environment ##
#$environmentToAdd = $repository.Environments.FindByName($environment).Id

$step = New-Object Octopus.Client.Model.DeploymentStepResource # Create new step object
$step.Name = $stepName
$step.Condition = [Octopus.Client.Model.DeploymentStepCondition]::Success # Step run condition (Success = Only run if previous step succeeds)
$step.Properties.Add("Octopus.Action.TargetRoles", $role)

$scriptAction = New-Object Octopus.Client.Model.DeploymentActionResource # Create the steps action type
$scriptAction.ActionType = "Octopus.Script" # This will define this as a Script step
$scriptAction.Name = $stepName
$scriptAction.Properties.Add("Octopus.Action.Script.ScriptBody", $scriptBody) # Put the script content into the steps script body

## Uncomment the below line to scope the step to an Environment ##
#$scriptAction.Environments.Add($environmentToAdd)

$step.Actions.Add($scriptAction) # Adds the step action to the step

# Foreach project in all projects: Get the deployment process, add the step we just built, modify deployment process with added step
foreach ($a in $allProjects) {

    $process = $repository.DeploymentProcesses.Get($a.DeploymentProcessId)
    $process.Steps.Add($step)
    $repository.DeploymentProcesses.Modify($process)

}
