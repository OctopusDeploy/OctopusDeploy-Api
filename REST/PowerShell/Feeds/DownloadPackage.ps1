$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"
$packageName = "packageName"
$packageVersion = "1.0.0.0"
$outputFolder = "/path/to/output/folder"

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get package details
$package = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/packages/packages-$packageName.$packageVersion" -Headers $header)

# Get package
$filePath = [System.IO.Path]::Combine($outputFolder, "$($package.PackageId).$($package.Version)$($package.FileExtension)")
Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/packages/$packageName.$packageVersion/raw" -Headers $header -OutFile $filePath
Write-Host "Downloaded file to $filePath"