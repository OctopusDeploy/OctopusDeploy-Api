$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-KEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"
$packageId = "your-package-id"

$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -eq $spaceName }

# Check for specific version of 1.0.0.6
$versionRange="[1.0.0.6,1.0.0.6]"
$specificVersionPackages = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/feeds/feeds-builtin/packages/versions?packageId=$($packageId)&versionRange=$versionRange&take=1" -Headers $header 
$specificPackage = $specificVersionPackages.Items | Select-Object -First 1
$specificPackage