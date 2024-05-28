$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://YOUR-OCTO-URL"
$octopusAPIKey = "API-#####"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"
$templateName = "Your Template Name"

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object { $_.Name -eq $spaceName }

# Get projects for space
$projectList = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header

# Get template id
$template = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/actiontemplates/all" -Headers $header) | Where-Object { $_.Name -eq $templateName }

$projectsUsingTemplate = @()
$projectsSkipped = @()

# Loop through projects
foreach ($project in $projectList) {
    
    $deploymentProcessLink = $project.Links.DeploymentProcess
    
    # Check if project is Config-as-Code
    if ($project.IsVersionControlled) {
        $defaultBranch = $project.PersistenceSettings.DefaultBranch
        $deploymentProcessLink = $deploymentProcessLink -Replace "{gitRef}", $defaultBranch
    }

    # Get deployment process and check steps for Action Template
    try {
        $deploymentProcess = Invoke-RestMethod -Method Get -Uri "$octopusURL$deploymentProcessLink" -Headers $header
        foreach ($step in $deploymentProcess.Steps) {
            if ($step.Actions[0].Properties.'Octopus.Action.Template.Id' -eq $template.Id) {
                $projectsUsingTemplate += $project.Name
            }
        }
    }
    catch {
        $projectsSkipped += $project.Name # Record project if we can't get the deployment process - usually due to CaC credentials
    }
}

Write-Host "Step template $($templateName) is used in the following $($projectsUsingTemplate.Count) projects:" -ForegroundColor Green
$projectsUsingTemplate | ForEach-Object {"* $PSItem"}
Write-Host "-----------------------------------"
Write-Host "The following projects were skipped. Please check version control credentials are up to date:" -ForegroundColor Red
$projectsSkipped | ForEach-Object {"* $PSItem"}
Write-Host "-----------------------------------"
