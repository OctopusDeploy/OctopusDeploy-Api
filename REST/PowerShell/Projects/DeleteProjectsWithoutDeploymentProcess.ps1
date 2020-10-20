$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://youroctopusurl"
$octopusAPIKey = "API-KEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get project
$projects = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header

# Loop through projects
foreach ($project in $projects)
{
    # Get deployment process
    $deploymentProcess = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/deploymentprocesses/$($project.DeploymentProcessId)" -Headers $header

    # Check to see if there's a process
    if (($null -eq $deploymentProcess.Steps) -or ($deploymentProcess.Steps.Count -eq 0))
    {
        # Delete project
        Invoke-RestMethod -Method Delete -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)" -Headers $header
    }
}