#This script will update the release notes of the current release

$OctopusURL = "" #URL of Octopus Server
$OctopusAPIKey = "" #API Key to authenticate to Octopus Server
$newreleasenotes = "" #New release note for the current Release

$header = @{ "X-Octopus-ApiKey" = $OctopusAPIKey }
$releaseurl = $OctopusParameters["Octopus.Web.ReleaseLink"].Replace("/app#","api")

$release = Invoke-WebRequest $OctopusURL/$releaseurl -Headers $header | select -ExpandProperty Content | ConvertFrom-Json

$release.ReleaseNotes = $newreleasenotes

Invoke-WebRequest $OctopusURL/$releaseurl -Method Put -Headers $header -Body ($release | ConvertTo-Json)