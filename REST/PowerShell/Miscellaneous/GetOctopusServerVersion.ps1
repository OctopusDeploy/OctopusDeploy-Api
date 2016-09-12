##CONFIG##
$OctopusAPIkey = "" #Your Octopus API Key
$OctopusURL = "" #Your Octopus Server root URL

##PROCESS##
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$ServerVersion = ((Invoke-WebRequest $OctopusURL/api -Method GET -Headers $header).content | ConvertFrom-Json).version
$ServerVersion

