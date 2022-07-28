# You can get this dll from NuGet
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll' 

# If $true, will just run a what-if
$previewOnly = $false

$octopusURI = "https://your-octopus-instance"
$apikey = "API-xxxxx"

$spaceName = "Default"
$projectNames = @("Project Red", "Project Blue", "Project Green", "Project Yellow") # Name of the Project(s) in which you want to add the step
$stepTemplateNamePre = 'Perform security polling check'                             # Name of Step Template
$stepTemplateNamePost = 'Post deployment checks'                                    # Name of Step Template
$stepNamePre = 'Security polling check'                                             # Custom Name you want to call your step in the project
$stepNamePost = 'Post deploy checks'                                                # Custom Name you want to call your step in the project
$targetRole = 'web-app-test'                                                        # Run this step on these deployment targets, leave empty for none
$runOnServer = 'false'                                                              # Set this to true to run the step on the Octopus Server (Must be string "true"|"false")
$environmentName = ''                                                               # Name of Environment on which you want this step to run

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint($octopusURI, $apikey)
$repository = New-Object Octopus.Client.OctopusRepository($endpoint)
$client = New-Object Octopus.Client.OctopusClient($endpoint)

# Get space
$space = $repository.Spaces.FindByName($spaceName)
$repositoryForSpace = $client.ForSpace($space)

$insertPreStepIndex = 0
$insertPostStepIndex = 0
$appendPostStepAtEnd = $true

#-------------------------------------------------------

function Get-AddedAlreadyStatus($actionTemplateId, $processSteps){
    foreach ($step in $processSteps) {
        foreach ($action in $step.Actions) {
            if ($action.Properties["Octopus.Action.Template.Id"].Value -eq $actionTemplateId){
                return $true;
            }
        }
    }

    return $false;
}

function Add-Action($stepName, $stepTemplateName, $append, $index, $processSteps){
    $actionTemplate = $repositoryForSpace.ActionTemplates.FindByName($stepTemplateName)
    $actionTemplateId = $actionTemplate.Id

    $alreadyAdded = Get-AddedAlreadyStatus $actionTemplateId  $processSteps

    if ($alreadyAdded -eq $true){
        Write-Host "--->    Step: $($stepTemplateName) - Already in project, will not add."  -ForegroundColor Yellow
        return;
    }
    
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
        $step.Properties["Octopus.Action.TargetRoles"] = Read-Host 'If $action.Properties["Octopus.Action.RunOnServer"] Is Not "true", You Must Enter a Target Role'
    }

    if ($previewOnly -eq $false){
        $step.Actions.Add($action)

        if($append -eq $true){
            $process.Steps.Add($step)
        } else {
            $process.Steps.Insert($index, $step)
        }
        Write-Host "--->    Step: $($stepTemplateName) - Adding step into project. " -ForegroundColor Green

        try {
            $repositoryForSpace.DeploymentProcesses.Modify($process)
        }
        catch {
            Write-Warning $_.Exception.InnerException.Details.Name.ToString()
        }
    }
}

#-------------------------------------------------------

foreach ($name in $projectNames) {
    $project = $repositoryForSpace.Projects.FindByName($name)
    Write-Host "-------------------------------------------"  -ForegroundColor Green
    Write-Host "--->  Project: $($name)"  -ForegroundColor Blue
    $process = $repositoryForSpace.DeploymentProcesses.Get($project.DeploymentProcessId)

    # reset indexes
    $insertPreStepIndex = 0
    $insertPostStepIndex = 0
    $appendPostStepAtEnd = $true

    # if first step is a manual intervention then set index to insert at to be 1
    if($process.Steps[0].Actions[0].ActionType -eq "Octopus.Manual") {
        $insertPreStepIndex = 1;
    }
    
    $environmentId = $repositoryForSpace.Environments.FindByName($environmentName).Id

    Add-Action $stepNamePre $stepTemplateNamePre $false $insertPreStepIndex $process.Steps

    # reload process as it's changed since we loaded it 
    $process = $repositoryForSpace.DeploymentProcesses.Get($project.DeploymentProcessId)

    Add-Action $stepNamePost $stepTemplateNamePost $appendPostStepAtEnd $insertPostStepIndex $process.Steps
}