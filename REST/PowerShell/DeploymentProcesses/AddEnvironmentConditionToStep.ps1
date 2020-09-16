# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"
$projectName = "MyProject"
$stepName = "Run a script"
$environmentNames = @("Development", "Test")
$environments = @()

try
{
    # Get space
    $space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

    # Get environments
    $environments += (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/environments/all" -Headers $header) | Where-Object {$environmentNames -contains $_.Name} | Select -Property Id

    # Get project
    $project = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.id)/projects/all" -Headers $header) | Where-Object {$_.Name -eq $projectName}

    # Get project deployment process
    $deploymentProcess = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/deploymentprocesses/$($project.DeploymentProcessId)" -Headers $header

    # Get specific step
    $step = $deploymentProcess.Steps | Where-Object {$_.Name -eq $stepName}

    # Loop through the actions of the step and apply environment(s)
    foreach ($action in $step.Actions)
    {
        # Add/upate environment(s)
        $action.Environments += $environments.Id
    }

    # Update the deployment process
    Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/deploymentprocesses/$($project.DeploymentProcessId)" -Headers $header -Body ($deploymentProcess | ConvertTo-Json -Depth 10)
}
catch
{
    Write-Host $_.Exception.Message
}