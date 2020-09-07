# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"
$projectName = "MyProject"

try
{
    # Get space
    $space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

    # Get project
    $project = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header) | Where-Object {$_.Name -eq $projectName}

    # Get releases for project
    $releases = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/releases" -Headers $header

    # Loop through list
    foreach ($release in $releases.Items)
    {
        # Delete release
        Invoke-RestMethod -Method Delete -Uri "$octopusURL/api/$($space.Id)/releases/$($release.Id)" -Headers $header
    }
}
catch
{
    Write-Host $_.Exception.Message
}