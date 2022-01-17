$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-KEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"
$packageId = "your-package-id"

$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -eq $spaceName }

# Get latest package version
$latestPackages = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/feeds/feeds-builtin/packages/versions?packageId=$($packageId)&take=1" -Headers $header 
$latestPackage = $latestPackages.Items | Select-Object -First 1
$latestPackage
