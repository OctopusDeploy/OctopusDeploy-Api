#Config
$OctopusAPIkey = "" #API Key to authenticate in Octopus
$OctopusURL = "" #Octopus server url

$TentacleURL = "" #Tentacle URL that you'll normally use on the Web UI for the discovery
$TentaclePort = "" #Tentacle Port

##Process
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$DiscoverData = Invoke-RestMethod "$OctopusURL/api/machines/discover?host=$TentacleURL&port=$TentaclePort&type=TentaclePassive" -Method Get -Headers $header

#$DiscoverData.Endpoint will hold the Tentacle URI and Thumbprint needed to create the Tentacle

#$DiscoverDate.Endpoint.URI
#$DiscoverData.Endpoint.Thumbprint