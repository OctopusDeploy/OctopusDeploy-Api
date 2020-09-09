# Define working variables
$octopusURL = "https://youroctourl/api"
$octopusAPIKey = "API-YOURAPIKEY"
$headers = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$spaceName = "Default"
$projectName = "Display URL to user"
$releaseVersion = "0.0.6"
$environmentName = "Development"

try {
    
    # Get space id
    $spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces/all" -Headers $headers -ErrorVariable octoError
    $space = $spaces | Where-Object { $_.Name -eq $spaceName }
    Write-Host "Using Space named $($space.Name) with id $($space.Id)"

    # Get project by name
    $projects = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $headers -ErrorVariable octoError
    $project = $projects | Where-Object { $_.Name -eq $projectName }
    Write-Host "Using Project named $($project.Name) with id $($project.Id)"

    # Get release by version
    $releases = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/releases" -Headers $headers -ErrorVariable octoError
    $release = $releases.Items | Where-Object { $_.Version -eq $releaseVersion }
    Write-Host "Using Release version $($release.Version) with id $($release.Id)"

    # Get environment by name
    $environments = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/environments/all" -Headers $headers -ErrorVariable octoError
    $environment = $environments | Where-Object { $_.Name -eq $environmentName }
    Write-Host "Using Environment named $($environment.Name) with id $($environment.Id)"

    # Create deployment
    $deploymentBody = @{
        ReleaseId     = $release.Id
        EnvironmentId = $environment.Id
    } | ConvertTo-Json

    Write-Host "Creating deployment with these values: $deploymentBody"
    $deployment = Invoke-RestMethod -Uri $octopusURL/api/$($space.Id)/deployments -Method POST -Headers $headers -Body $deploymentBody
}
catch {
    Write-Host "There was an error during the request: $($octoError.Message)"
}