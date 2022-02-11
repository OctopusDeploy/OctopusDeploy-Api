$ErrorActionPreference = "Stop";

####
## Define working variables
####
$octopusURL = "https://myoctopusurl"
$octopusAPIKey = "API-YOURKEYHERE"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"

# Project group to change lifecycle for
$projectGroupName = "MyProjectGroup"
# New lifecycle to assign (must exist before running script)
$newLifecycleName = "MyNewLifecycle"

# What-If flag (set to true to test changes without comitting them)
$whatIf = $true

####
## Perform API Calls
####

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object { $_.Name -eq $spaceName }

# Get new lifecycle
$newLifecycle = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/lifecycles/all" -Headers $header) | Where-Object { $_.Name -eq $newLifecycleName }

# Get project groups for space
$projectGroup = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projectgroups/all" -Headers $header) | Where-Object { $_.Name -eq $projectGroupName }

# Get projects for specified project group
$projectList = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projectgroups/$($projectGroup.Id)/projects" -Headers $header)

# Loop through projects
foreach ($project in $projectList.Items) {

    $project.LifecycleId = $($newLifecycle.Id)

    if (!$whatIf) {
        Write-Host -ForegroundColor Green "`tUpdating project lifecycle for $($project.Name)"
        Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)" -Headers $header -Body ($project | ConvertTo-Json -Depth 10)
    }
    else {
        Write-Host -ForegroundColor Yellow "`tWhat if set to true - would update project lifecycle for $($project.Name)"
    }
}
