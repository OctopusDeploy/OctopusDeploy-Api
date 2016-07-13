$OctopusAPIkey = "" #Your Octopus API Key
$OctopusURL = "" #Your Octopus base url

$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

(Invoke-WebRequest "$OctopusURL/api/feeds" -Headers $header -Method Get).content | ConvertFrom-Json | select -ExpandProperty items