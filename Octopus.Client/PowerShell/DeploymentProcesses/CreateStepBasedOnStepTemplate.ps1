# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll' 
 
$apikey = 'API-KEY' # Get this from your profile
$octopusURI = 'https://localhost' # Your server address

$projectNames = @('') # Name of the Project(s) in which you want to add the step, leave empty string for ALL
$stepTemplateName = '' # Name of Step Template
$stepName = '' # Custom Name you want to call your step in the project
$targetRole = '' # Run this step on these deployment targets, leave empty for none
$runOnServer = '' # Set this to true to run the step on the Octopus Server (Must be string "true"|"false")
$environmentName = '' # Name of Environment on which you want this step to run

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

foreach ($name in $projectNames) {
    if (![string]::IsNullOrEmpty($projectNames)) {
        $projects = $repository.Projects.FindByName($name)
    }
    else {
        $projects = $repository.Projects.GetAll()
    }

    foreach($project in $projects){
        $process = $repository.DeploymentProcesses.Get($project.DeploymentProcessId)

        $environmentId = $repository.Environments.FindByName($environmentName).Id

        $actionTemplate = $repository.ActionTemplates.FindByName($stepTemplateName)

        $step = New-Object Octopus.Client.Model.DeploymentStepResource
        $step.Name = $stepName
        $step.Condition = [Octopus.Client.Model.DeploymentStepCondition]::Success
        if (![string]::IsNullOrEmpty($targetRole)) {
            $step.Properties["Octopus.Action.TargetRoles"] = $targetRole
        }

        $action = New-Object Octopus.Client.Model.DeploymentActionResource
        $action.Name = $stepName
        $action.ActionType = $actionTemplate.ActionType

        if (![string]::IsNullOrEmpty($environmentName)) {
            $action.Environments.Add($environmentId) | Out-Null
        }
        
        #Generic properties
        foreach ($property in $actionTemplate.Properties.GetEnumerator()) {
            $action.Properties[$property.Key] = $property.Value
            $action.Properties["Octopus.Action.RunOnServer"] = $runOnServer
        }

        $action.Properties["Octopus.Action.Template.Id"] = $actionTemplate.Id
        $action.Properties["Octopus.Action.Template.Version"] = $actionTemplate.Version

        #Step template specific properties
        foreach ($parameter in $actionTemplate.Parameters) {
            #This is just a sample, provide your own custom values here or leave default value if you are happy with it
            $action.Properties[$parameter.Name] = $parameter.DefaultValue
        }

        if ($action.Properties["Octopus.Action.RunOnServer"].Value -eq $false -and [string]::IsNullOrEmpty($targetRole)) {
            write-host ""
            $step.Properties["Octopus.Action.TargetRoles"] = Read-Host 'If $action.Properties["Octopus.Action.RunOnServer"] Is Not "true", You Must Enter a Target Role'
        }

        $step.Actions.Add($action)
        $process.Steps.Add($step)

        try {
            $repository.DeploymentProcesses.Modify($process)
        }
        catch {
            Write-Warning $_.Exception.InnerException.Details.Name.ToString()
        }
    }
}