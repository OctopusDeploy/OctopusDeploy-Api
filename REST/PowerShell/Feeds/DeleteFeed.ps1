$OctopusAPIkey = "" #Your Octopus API Key
$OctopusURL = "" #Your Octopus base url

$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$feedID = "" #ID of the feed you want to delete. The best way to get this ID is by going to Library -> External feeds -> [Edit] on the feed you want to delete -> Check the ID

Invoke-WebRequest "$OctopusURL/api/feeds/$feedID" -Headers $header -Method Delete