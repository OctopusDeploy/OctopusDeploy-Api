# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"
$projectName = "MyProject"

try
{
    # Get space
    $space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

    # Get project
    $project = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header) | Where-Object {$_.Name -eq $projectName}

    # Get project triggers
    $projectTriggers = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/triggers" -Headers $header

    # Loop through triggers
    foreach ($projectTrigger in $projectTriggers.Items)
    {
        # Disable the trigger
        $projectTrigger.IsDisabled = $true
        Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/projecttriggers/$($projectTrigger.Id)" -Body ($projectTrigger | ConvertTo-Json -Depth 10) -Headers $header
    }
}
catch
{
    Write-Host $_.Exception.Message
}