$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

# Specify the Space to search in
$spaceName = "Default"

$customExecutablePathToFind = "helm-3.2.4.exe"

$octopusURL = $octopusURL.TrimEnd('/')

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object { $_.Name -eq $spaceName }

Write-Host "Looking for usages of helm executable '$customExecutablePathToFind' in space: '$spaceName'"

# Get all projects
$projects = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header

# Loop through projects
foreach ($project in $projects) {

    $deploymentProcessLink = $project.Links.DeploymentProcess
    
    # Check if project is Config-as-Code
    if ($project.IsVersionControlled) {
        # Get default Git branch for Config-as-Code project
        $defaultBranch = $project.PersistenceSettings.DefaultBranch
        $deploymentProcessLink = $deploymentProcessLink -Replace "{gitRef}", $defaultBranch
    }
    # Get project deployment process
    $deploymentProcess = Invoke-RestMethod -Method Get -Uri "$octopusURL$deploymentProcessLink" -Headers $header

    # Loop through steps
    foreach ($step in $deploymentProcess.Steps) {
        $actions = @($step.Actions)
        $action = $actions | Select-Object -First 1
        if ($action.ActionType -ine "Octopus.HelmChartUpgrade") {
            continue;
        }

        if ($null -ne $action.Properties."Octopus.Action.Helm.CustomHelmExecutable") {
            $customExecutablePath = $action.Properties."Octopus.Action.Helm.CustomHelmExecutable"
            if ([string]::IsNullOrWhitespace($customExecutablePath)) { continue; }
            if($customExecutablePath -like "*$customExecutablePathToFind*") {
                Write-Host "Found custom helm executable in Project '$($project.Name)', step: $($step.Name)" -ForegroundColor Green
            }
        }
    }
    
}
