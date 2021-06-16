$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"
$projectId = "Projects-101"
$channelName = "Channel Name"

# Get space
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -eq $spaceName }

# Create channel json payload
$jsonPayload = @{
    ProjectId = $projectId;
    Name = $channelName
    Description = ""
    IsDefault = $False
}

# Create channel
Invoke-RestMethod -Method Post -Uri "$octopusURL/api/$($space.Id)/channels" -Body ($jsonPayload | ConvertTo-Json -Depth 10) -Headers $header