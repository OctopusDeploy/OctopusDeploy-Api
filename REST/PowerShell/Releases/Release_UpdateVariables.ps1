##CONFIG
$OctopusURL = "" #Octopus URL
$OctopusAPIKey = "" #Octopus API Key
$releaseId = "" #Release Id

##PROCESS##
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }


Invoke-WebRequest $OctopusURL/api/releases/$releaseId/snapshot-variables -Method Post -Headers $header
