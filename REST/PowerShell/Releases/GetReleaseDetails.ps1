$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$projectName = "MyProject"
$releaseVersion = "1.0.0.0"
$spaceName = "Default"

# Get space
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -eq $spaceName }

# Get project
$projects = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/projects?partialName=$([uri]::EscapeDataString($projectName))&skip=0&take=100" -Headers $header 
$project = $projects.Items | Where-Object { $_.Name -eq $projectName }

# Get release
$releases = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/releases" -Headers $header
$release = $releases.Items | Where-Object { $_.Version -eq $releaseVersion }

# Display release packages
$release.SelectedPackages | Format-List

# Display release
$release