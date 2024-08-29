# Use the script below in a "Run a Script" step to fail a deployment where "HasWarningsOrErrors" is true in the JSON for the $serverTaskID.

$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://YOUR_OCTOPUS_URL"
$octopusAPIKey = "API-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceID = $OctopusParameters["Octopus.Space.Id"]
$serverTaskID = $OctopusParameters["Octopus.Task.Id"]

$serverTaskJSON = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($spaceID)/tasks/$($serverTaskID)" -Headers $header
If ($serverTaskJSON.HasWarningsOrErrors) {
    Write-Error "This deployment contains warnings or errors. Failing deployment..."
}
