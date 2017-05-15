$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest;

# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll' 

$apikey = 'API-XXXXXXXXXXXXXXXXXXXXXXXXXX' # Get this from your profile
$octopusURI = 'http://localhost' # Your server address

$projectName = "MyProject"
$stepTemplateName = "MyStepTemplate"
$stepName = "My Step" 
$targetRole = "instance-role"

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

$project = $repository.Projects.FindByName($projectName)
$process = $repository.DeploymentProcesses.Get($project.DeploymentProcessId)


$actionTemplate = $repository.ActionTemplates.FindByName($stepTemplateName)

$step = New-Object Octopus.Client.Model.DeploymentStepResource
$step.Name = $stepName
$step.Condition = [Octopus.Client.Model.DeploymentStepCondition]::Success
$step.Properties["Octopus.Action.TargetRoles"] = $targetRole

$action = New-Object Octopus.Client.Model.DeploymentActionResource
$action.Name = $stepName
$action.ActionType = $actionTemplate.ActionType

#Generic properties
foreach ($property in $actionTemplate.Properties.GetEnumerator()) {
    $action.Properties[$property.Key] = $property.Value
}

$action.Properties["Octopus.Action.Template.Id"] = $actionTemplate.Id
$action.Properties["Octopus.Action.Template.Version"] = $actionTemplate.Version

#Step template specific properties
foreach ($parameter in $actionTemplate.Parameters) {
    #This is just a sample, provide your own custom values here or leave default value if you are happy with it
    $action.Properties[$parameter.Name] = $parameter.DefaultValue
}

$step.Actions.Add($action)
$process.Steps.Add($step)

$repository.DeploymentProcesses.Modify($process)