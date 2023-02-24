$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://YOUR_OCTOPUS.octopus.app"
$octopusAPIKey = "API-12341234123412341234"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$projectName = "YOUR_PROJECT_NAME"
$releaseVersion = "YOUR_RELEASE_VERSION"
$spaceName = "YOUR_SPACE_NAME"

# Get space
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -eq $spaceName }

# Get project
$projects = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/projects?partialName=$([uri]::EscapeDataString($projectName))&skip=0&take=100" -Headers $header 
$project = $projects.Items | Where-Object { $_.Name -eq $projectName }

# Get release
$releases = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/releases" -Headers $header
$release = $releases.Items | Where-Object { $_.Version -eq $releaseVersion }

Write-Host "Release $releaseVersion of $projectName has the following packages and versions:"
# Get deployment process
$process = Invoke-RestMethod -Uri "$octopusURL$($release.Links.ProjectDeploymentProcessSnapshot)" -Headers $header
foreach ($step in $process.Steps) {
    $packages = $step.Actions.Packages
    if ($null -ne $packages) {
        foreach($package in $packages) {
            # Match the package version with the package name
            $packageVersion = $release.SelectedPackages | Where-Object { $_.StepName -eq $step.Name }
            Write-Host "   Step '$($step.Name)' is using package '$($package.PackageId)' version '$($packageVersion.Version)'."
        }
    }
}
