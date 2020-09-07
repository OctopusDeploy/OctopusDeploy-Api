# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"
$projectName = "MyProject"
$runbookName = "MyRunbook"

try
{
    # Get space
    $space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

    # Get project
    $project = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header) | Where-Object {$_.Name -eq $projectName}

    # Create json payload
    $jsonPayload = @{
        Name = $runbookName
        ProjectId = $project.Id
        EnvironmentScope = "All"
        RunRetentionPolicy = @{
            QuantityToKeep = 100
            ShouldKeepForever = $false
        }   
    }

    # Create the runbook
    Invoke-RestMethod -Method Post -Uri "$octopusURL/api/$($space.Id)/runbooks" -Body ($jsonPayload | ConvertTo-Json -Depth 10) -Headers $header
}
catch
{
    Write-Host $_.Exception.Message
}