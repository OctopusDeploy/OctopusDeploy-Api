# Octopus Url
$OctopusUrl = "https://your-octopus-url"

# API Key
$APIKey = "API-XXXXXXXXX"

# Space where machines exist
$spaceName = "Default" 

$header = @{ "X-Octopus-ApiKey" = $APIKey }

# Get SpaceId
Write-Host "Getting list of all spaces: $OctopusUrl/api/Spaces?skip=0&take=100000"
$spaceList = (Invoke-RestMethod "$OctopusUrl/api/Spaces?skip=0&take=100000" -Headers $header)
$space = $spaceList.Items | Where-Object { $_.Name -eq $spaceName} | Select-Object -First 1
$spaceId = $space.Id

# Get List of All Channels for Space (these contain the LifecycleIds)
$channelsUrl = "$OctopusUrl/api/$spaceId/channels?skip=0&take=100000"
Write-Host "Getting list of channels: $channelsUrl"

$channelsResource = (Invoke-RestMethod $channelsUrl -Headers $header)
$channels = $channelsResource.Items
$lifecyclesWithoutReleases = @()

foreach($channel in $channels){
    $channelId = $channel.Id
    $channelName = $channel.Name
    $channelLifecycleId = $channel.LifecycleId
    $channelProjectId = $channel.ProjectId
    if($null -eq $channelLifecycleId) {
        $channelLifecycleId = "[Default Lifecycle]"
    }
    $channelReleasesUrl = "$OctopusUrl/api/$spaceId/channels/$channelId/releases?skip=0&take=10000"
    $channelReleasesResource = (Invoke-RestMethod $channelReleasesUrl -Headers $header)
    $channelReleases = $channelReleasesResource.Items
    if($channelReleases.Count -eq 0) {
        $lifecyleDesc =  "Channel: $channelName ($channelId),ProjectId: $channelProjectId, LifecycleId: $channelLifecycleId"
        if( -not $lifecyclesWithoutReleases.Contains($lifecyleDesc)) {
            $lifecyclesWithoutReleases += "$lifecyleDesc"
        }
    }
}

$totalFound = $lifecyclesWithoutReleases.Count
Write-Host "Total Lifecyles with no releases: $totalFound"

if ($totalFound -gt 0) {   
    $tempFile = [System.IO.Path]::GetTempFileName() 
    $lifecyclesWithoutReleases | Out-File -append $tempFile
    Write-Host "Found the following lifecycles with no releases:" -ForegroundColor Red
    foreach ($lifecycle in $lifecyclesWithoutReleases) {
        Write-Host $lifecycle
    }
    Write-Host "Written lifecycles with no releases to: $tempFile"
}