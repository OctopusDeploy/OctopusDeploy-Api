$octopusURI = "https://octopus.url" # Replace this with your octopus URL
$apiKey = "API-1232" # Replace this with your API key http://docs.octopusdeploy.com/display/OD/How+to+create+an+API+key

$header =  @{ "X-Octopus-ApiKey" = $apiKey }

$nodes = Invoke-WebRequest -Uri "$octopusURI/api/octopusservernodes" -Headers $header | ConvertFrom-Json
$nodes.Items | % {
    $id = $_.Id
    Invoke-WebRequest -Uri "$octopusURI/api/octopusservernodes/$id" -Headers $header -Method Delete
}
