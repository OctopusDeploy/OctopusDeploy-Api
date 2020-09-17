# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"
$projectName = "MyProject"
$runbookName = "MyRunbook"
$snapshotName = "Snapshot 9PNENH6"

try
{
    # Get space
    $space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

    # Get project
    $project = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header) | Where-Object {$_.Name -eq $projectName}

    # Get runbook
    $runbook = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/runbooks/all" -Headers $header) | Where-Object {$_.Name -eq $runbookName -and $_.ProjectId -eq $project.Id}

    # Get the runbook process
    $runbookProcess = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/runbookProcesses/$($runbook.RunbookProcessId)" -Headers $header

    # Loop through steps and gather referenced packages
    $selectedPackages = @()
    foreach ($step in $runbookProcess.Steps)
    {
        # Loop through the actions of the step
        foreach ($action in $step.Actions)
        {
            # Check to see if action references a package
            if ($null -ne $action.Packages)
            {
                # Loop through selected packages
                foreach ($package in $action.Packages)
                {
                    # Get latest version of package
                    $packageVersion = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/feeds/$($package.FeedId)/packages/versions?packageId=$($package.PackageId)&take=1" -Headers $header).Items[0].Version
                    
                    # Add to selected packages array
                    $selectedPackages += @{
                        ActionName = $action.Name
                        Version = $packageVersion
                        PackageReferenceName = ""
                    }
                }
            }
        }
    }

    # Create json payload
    $jsonPayload = @{
        ProjectId = $project.Id
        RunbookId = $runbook.Id
        Name = $snapshotName
        SelectedPackages = $selectedPackages
    }

    # Publish the snapshot
    Invoke-RestMethod -Method Post -Uri "$octopusURL/api/$($space.Id)/runbookSnapShots?publish=true" -Body ($jsonPayload | ConvertTo-Json -Depth 10) -Headers $header
}
catch
{
    Write-Host $_.Exception.Message
}