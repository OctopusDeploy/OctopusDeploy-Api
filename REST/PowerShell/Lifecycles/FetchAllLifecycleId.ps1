$server = "https://<Your_Url>" #your octopus server
$apiKey = "API-<Key>" #you'll need to generate an API

$command = $($server + "/api/lifecycles")

$lifecycles = Invoke-RestMethod -Method Get -Uri $command  -Header @{"X-Octopus-ApiKey"=$apiKey}
$lifecycles.Items | Format-Table Id, Name
