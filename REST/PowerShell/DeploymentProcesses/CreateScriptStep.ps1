$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"
$role = "My role"
$scriptBody = "Write-Host `"Hello world`""

# Project details
$projectName = "MyProject"


# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get project
$project = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header) | Where-Object {$_.Name -eq $projectName}

# Get deployment process
$deploymentProcess = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/deploymentprocesses/$($project.DeploymentProcessId)" -Headers $header)

# Get current steps
$steps = $deploymentProcess.Steps

# Add new step to process
$steps += @{
    Name = "Run a script"
    Properties = @{
    'Octopus.Action.TargetRoles' = $role
    }
    Condition = "Success"
    StartTrigger = "StartAfterPrevious"
    PackageRequirement = "LetOctopusDecide"
    Actions = @(
    @{
        ActionType = "Octopus.Script"
        Name = "Run a script"
        Environments = @()
        ExcludedEnvironments = @()
        Channels = @()
        TenantTags = @()
        Properties = @{
            'Octopus.Action.RunOnServer' = "false"
            'Octopus.Action.EnabledFeatures' = ""
            'Octopus.Action.Script.ScriptSource' = "Inline"
            'Octopus.Action.Script.Syntax' = "PowerShell"
            'Octopus.Action.Script.ScriptFilename' = $null
            'Octopus.Action.Script.ScriptBody' = $scriptBody
        }
        Packages = @()
        IsDisabled = $false
        WorkerPoolId = ""
        WorkerPoolVariable = ""
        Container = @{
            "FeedId" = $null
            "Image" = $null
        }
        CanBeUsedForProjectVersioning = $false
        IsRequired = $false
    }
    )
}

# Convert steps to json
$deploymentProcess.Steps = $steps
$jsonPayload = $deploymentProcess | ConvertTo-Json -Depth 10

# Submit request
Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/deploymentprocesses/$($project.DeploymentProcessId)" -Headers $header -Body $jsonPayload