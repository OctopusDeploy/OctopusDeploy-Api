$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"
$feedName = "nuget.org"
$feedURI = "https://api.nuget.org/v3/index.json"
$downloadAttempts = 5
$downloadRetryBackoffSeconds = 10
# Set to $True to use the Extended API.
$useExtendedApi = $False
# Optional
$feedUsername = ""
$feedPassword = ""

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

$body = @{
    Id = $null
    FeedType = "NuGet"
    DownloadAttempts = $downloadAttempts
    DownloadRetryBackoffSeconds = $downloadRetryBackoffSeconds
    EnhancedMode = $useExtendedApi
    Name = $feedName
    FeedUri = $feedURI
}
if(-not ([string]::IsNullOrEmpty($feedUsername))) 
{
    $body.Username = $feedUsername
}
if(-not ([string]::IsNullOrEmpty($feedPassword))) 
{
    $body.Password = $feedPassword
}

# Create Feed
Invoke-RestMethod -Method Post -Uri "$octopusURL/api/$($space.Id)/feeds" -Body ($body | ConvertTo-Json -Depth 10) -Headers $header