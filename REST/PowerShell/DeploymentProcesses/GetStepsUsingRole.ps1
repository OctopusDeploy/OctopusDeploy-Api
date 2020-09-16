# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"
$roleName = "My role"

try
{
    # Get space
    $space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

    # Get projects for space
    $projectList = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header

    # Loop through projects
    foreach ($project in $projectList)
    {
        # Get project deployment process
        $deploymentProcess = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/deploymentprocesses/$($project.DeploymentProcessId)" -Headers $header

        # Get steps
        foreach ($step in $deploymentProcess.Steps)
        {
            if (($null -ne $step.Properties.'Octopus.Action.TargetRoles') -and ($step.Properties.'Octopus.Action.TargetRoles'.Value.Split(',') -Icontains $roleName ))
            {
                Write-Host "Step $($step.Name) of $($project.Name) is using role $roleName"
            }
        }
    }
}
catch
{
    Write-Host $_.Exception.Message
}