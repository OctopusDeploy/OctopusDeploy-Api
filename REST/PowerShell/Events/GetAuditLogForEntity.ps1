$EntityId = ""  #the id of the object you want to get the events for. Usually can be obtained from the address bar in the browser
$OctopusURL = "" #url of your octopus server
$OctopusAPIkey = "" #API Key to authenticate in Octopus.

$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$json = (Invoke-WebRequest $OctopusURL/api/events?regarding=$EntityId -Headers $header -Method Get -UseBasicParsing).content
($json | ConvertFrom-Json).items | select-object {$_.Username, $_.Occurred, $_.Message}
