# Define working variables
$octopusURL = "https://youroctopusurl"
$octopusAPIKey = "API-KEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"
$packageId = "PackageId"

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
            $packages = $step.Actions.Packages
            if ($null -ne $packages)
            {
                $packageIds = $packages | Where-Object {$_.PackageId -eq $packageId}
                if($packageIds.Count -gt 0) {
                    Write-Host "Step: $($step.Name) of project: $($project.Name) is using package '$packageId'."
                }
            }
        }
    }
}
catch
{
    Write-Host $_.Exception.Message
}