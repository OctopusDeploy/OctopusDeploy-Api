$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-KEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$targetRole = "octofx-web"

$spaceName = "Default"
$projectName = "A project"
$communityStepTemplateName = "Run Octopus Deploy Runbook"

# Get space
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -eq $spaceName }

# Get community step templates
$communityActionTemplatesList = Invoke-RestMethod -Uri "$octopusURL/api/communityactiontemplates?skip=0&take=2000" -Headers $header 

Write-Host "Checking if $communityStepTemplateName is installed in Space $spaceName"
$installStepTemplate = $true
$stepTemplatesList = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/actiontemplates?skip=0&take=2000&partialName=$([uri]::EscapeDataString($communityStepTemplateName))" -Headers $header 
foreach ($stepTemplate in $stepTemplatesList.Items) {
    
    
    if ($null -eq $stepTemplate.CommunityActionTemplateId) {
        Write-Host "The step template $($stepTemplate.Name) is not a community step template, moving on."
        continue
    }

    if ($stepTemplate.Name.ToLower().Trim() -eq $communityStepTemplateName.ToLower().Trim()) {
        Write-Host "The step template $($stepTemplate.Name) matches $communityStepTemplateName.  No need to install the step template."

        $communityActionTemplate = $communityActionTemplatesList.Items | Where-Object { $_.Id -eq $stepTemplate.CommunityActionTemplateId }                

        if ($null -eq $communityActionTemplate) {
            Write-Host "Unable to find the community step template in the library, skipping the version check."
            $installStepTemplate = $false
            break
        }

        if ($communityActionTemplate.Version -eq $stepTemplate.Version) {
            Write-Host "The step template $($stepTemplate.Name) is on version $($stepTemplate.Version) while the matching community template is on version $($communityActionTemplate.Version).  The versions match.  Leaving the step template alone."
            $installStepTemplate = $false
        }
        else {
            Write-Host "The step template $($stepTemplate.Name) is on version $($stepTemplate.Version) while the matching community template is on version $($communityActionTemplate.Version).  Updating the step template."

            $actionTemplate = Invoke-RestMethod -Method Put -Uri "$octopusURL/api/communityactiontemplates/$($communityActionTemplate.Id)/installation/$($space.Id)" -Headers $header 
            Write-Host "Succesfully updated the step template.  The version is now $($actionTemplate.Version)"

            $installStepTemplate = $false
        }
        
        break
    }
}

if ($installStepTemplate -eq $true) {
    $communityActionTemplateToInstall = $null
    foreach ($communityStepTemplate in $communityActionTemplatesList.Items) {
        if ($communityStepTemplate.Name.ToLower().Trim() -eq $communityStepTemplateName.ToLower().Trim()) {
            $communityActionTemplateToInstall = $communityStepTemplate
            break
        }
    }

    if ($null -eq $communityActionTemplateToInstall) {
        Write-Host -Message "Unable to find $communityStepTemplateName.  Please either re-sync the community library or check the names.  Exiting." -ForegroundColor Red
        exit 1
    }

    Write-Host "Installing the step template $communityStepTemplateName to $($space.Name)."
    $actionTemplate = Invoke-RestMethod -Method Post -Uri "$octopusURL/api/communityactiontemplates/$($communityActionTemplateToInstall.Id)/installation/$($space.Id)" -Headers $header 
    Write-Host "Succesfully installed the step template.  The Id of the new action template is $($actionTemplate.Id)"
}
else {
    foreach ($stepTemplate in $stepTemplatesList.Items) {
        if ($stepTemplate.Name.ToLower().Trim() -eq $communityStepTemplateName.ToLower().Trim()) {
            $actionTemplate = $stepTemplate
            break
        }
    }
}


# Get project
$projects = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/projects?partialName=$([uri]::EscapeDataString($projectName))&skip=0&take=100" -Headers $header 
$project = $projects.Items | Where-Object { $_.Name -eq $projectName }

# Get deployment process
$deploymentProcess = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/deploymentprocesses/$($project.DeploymentProcessId)" -Headers $header)

# Get current steps
$steps = $deploymentProcess.Steps

# Check existing steps for step template based on Id
foreach ($step in $steps) {
    if ($step.Actions[0].Properties.'Octopus.Action.Template.Id' -eq $actionTemplate.Id) {
        Write-Warning "Community step template '$communityStepTemplateName' already exists in project, exiting"
        break;
    }
}

$ActionProperties = @{
    'Octopus.Action.Script.ScriptSource' = $actionTemplate.Properties.'Octopus.Action.Script.ScriptSource'
    'Octopus.Action.Script.Syntax'       = $actionTemplate.Properties.'Octopus.Action.Script.Syntax'
    'Octopus.Action.Script.ScriptBody'   = $actionTemplate.Properties.'Octopus.Action.Script.ScriptBody'
    'Octopus.Action.Template.Id'         = $actionTemplate.Id
    'Octopus.Action.Template.Version'    = $actionTemplate.Version
}

# Add parameters with a default value
foreach ($parameter in $actionTemplate.Parameters) {
    if (-not $ActionProperties.ContainsKey($parameter.Name)) {
        if (-not [string]::IsNullOrWhitespace($parameter.DefaultValue)) {
            $ActionProperties | Add-Member -NotePropertyName $parameter.Name -NotePropertyValue $parameter.DefaultValue
        }
    }
    else {
        Write-Host "ActionProperty already has a value for $($parameter.Name)"
    }
}

# Add the step
$steps += @{
    Name               = "$communityStepTemplateName"
    Properties         = @{
        'Octopus.Action.TargetRoles' = $targetRole
    }
    Condition          = "Success"
    StartTrigger       = "StartAfterPrevious"
    PackageRequirement = "LetOctopusDecide"
    Actions            = @(
        @{
            ActionType                    = $actionTemplate.ActionType
            Name                          = "$communityStepTemplateName"
            Environments                  = @()
            ExcludedEnvironments          = @()
            Channels                      = @()
            TenantTags                    = @()
            Properties                    = $ActionProperties
            Packages                      = $actionTemplate.Packages
            IsDisabled                    = $false
            WorkerPoolId                  = ""
            WorkerPoolVariable            = ""
            Container                     = @{
                "FeedId" = $null
                "Image"  = $null
            }
            CanBeUsedForProjectVersioning = $false
            IsRequired                    = $false
        }
    )
}

# Convert steps to json
$deploymentProcess.Steps = $steps
$jsonPayload = $deploymentProcess | ConvertTo-Json -Depth 10

# Update deployment process
Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/deploymentprocesses/$($project.DeploymentProcessId)" -Headers $header -Body $jsonPayload