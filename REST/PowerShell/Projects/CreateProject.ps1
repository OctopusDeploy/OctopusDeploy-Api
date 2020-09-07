# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"
$projectName = "MyProject"
$projectDescription = "MyDescription"
$projectGroupName = "Default project group"
$lifecycleName = "Default lifecycle"

try
{
    # Get space
    $space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

    # Get project group
    $projectGroup = (Invoke-RestMethod -Method Get "$octopusURL/api/$($space.Id)/projectgroups/all" -Headers $header) | Where-Object {$_.Name -eq $projectGroupName}

    # Get Lifecycle
    $lifeCycle = (Invoke-RestMethod -Method Get "$octopusURL/api/$($space.Id)/lifecycles/all" -Headers $header) | Where-Object {$_.Name -eq $lifecycleName}

    # Create project json payload
    $jsonPayload = @{
        Name = $projectName
        Description = $projectDescription
        ProjectGroupId = $projectGroup.Id
        LifeCycleId = $lifeCycle.Id
    }

    # Create project
    Invoke-RestMethod -Method Post -Uri "$octopusURL/api/$($space.Id)/projects" -Body ($jsonPayload | ConvertTo-Json -Depth 10) -Headers $header
}
catch
{
    Write-Host $_.Exception.Message
}