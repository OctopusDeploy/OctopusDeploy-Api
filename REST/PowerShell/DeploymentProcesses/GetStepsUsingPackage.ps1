$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://octopus-url"
$octopusAPIKey = "API-XXXXXXXXXXXXXXXXXXXXXXXXX"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"
$packageId = "package-id"

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object { $_.Name -eq $spaceName }

# Get projects for space
$projectList = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header

# Loop through projects
foreach ($project in $projectList) {
    
    $deploymentProcessLink = $project.Links.DeploymentProcess
    
    # Check if project is Config-as-Code
    if ($project.IsVersionControlled) {
        # Get default Git branch for Config-as-Code project
        $defaultBranch = $project.PersistenceSettings.DefaultBranch
        $deploymentProcessLink = $deploymentProcessLink -Replace "{gitRef}", $defaultBranch
    }

    $deploymentProcess = Invoke-RestMethod -Method Get -Uri "$octopusURL$deploymentProcessLink" -Headers $header

    # Get steps and check step for specified package
    foreach ($step in $deploymentProcess.Steps) {
        $packages = $step.Actions.Packages
        if ($null -ne $packages) {
            $package = $packages | Where-Object { $_.PackageId -eq $packageId }
            if ($package.PackageId -eq $packageId) {
                Write-Host "Step: $($step.Name) of project: $($project.Name) is using package '$packageId'."
            }
        }
    }
}