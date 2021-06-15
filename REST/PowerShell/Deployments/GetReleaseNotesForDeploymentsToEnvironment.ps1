$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-YOURKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"
$environmentName = "Production"
$deploymentsQueuedAfter = "2021-06-01"

# Get space
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -eq $spaceName }

# Get environment
$environmentsResources = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/environments?partialName=$([uri]::EscapeDataString($environmentName))&skip=0&take=100" -Headers $header 
$environments = ($environmentsResources.Items | Where-Object { $_.Name -eq $environmentName } | ForEach-Object {"environments=$($_.Id)"}) -Join "&"

# Get Project groups
$projectGroupsResource = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/projectgroups?skip=0&take=100" -Headers $header 
$projectGroups = ($projectGroupsResource.Items | ForEach-Object {"projectGroups=$($_.Id)"}) -Join "&"

# Get events
$eventsUrl = "$octopusURL/api/$($space.Id)/events?includeSystem=false&eventCategories=DeploymentQueued&documentTypes=Deployments&from=$($deploymentsQueuedAfter)T00%3A00%3A00%2B00%3A00&$($projectGroups)&$($environments)"

$events = @()
$response = $null
do {
    $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { $eventsUrl }
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
    $events += $response.Items
} while ($response.Links.'Page.Next')

$releaseItems=@()
foreach($event in $events)
{
    # Get Release Id
    $releaseId = $event.RelatedDocumentIds | Where-Object {$_ -like "Releases-*"} | Select-Object -First 1
    $projectId = $event.RelatedDocumentIds | Where-Object {$_ -like "Projects*"} | Select-Object -First 1
    $project = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/projects/$projectId" -Headers $header 
    $release = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/releases/$releaseId" -Headers $header 
    if(![string]::IsNullOrWhiteSpace($release.ReleaseNotes)) {
        $releaseItem = [PSCustomObject]@{
            Project = $project.Name;
            Version = $release.Version;
            Created = $event.Occurred;
            ReleaseNotes = $release.ReleaseNotes
        }
        $releaseItems += $releaseItem
    }
}
$releaseItems | Select-Object * | Format-Table
