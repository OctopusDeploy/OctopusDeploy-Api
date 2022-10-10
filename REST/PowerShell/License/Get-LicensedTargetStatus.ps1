$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$licenseStatus = Invoke-RestMethod -Uri "$octopusUrl/api/licenses/licenses-current-status" -Headers $header

$targets = $licenseStatus.Limits | Where-Object { $_.Name -eq "Targets" }

$utilizedTargetCount = $targets.CurrentUsage
$licensedTargetCount = $targets.EffectiveLimit

if($targets.IsUnlimited)
{
    Write-Host "Using $utilizedTargetCount targets of unlimited licensed targets."
}
else {
    Write-Host "Using $utilizedTargetCount targets of $licensedTargetCount licensed targets."
}
