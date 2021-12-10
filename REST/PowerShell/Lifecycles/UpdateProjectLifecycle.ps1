$ErrorActionPreference = "Stop";

####
## Define working variables
####
$octopusURL = "https://myoctopusurl"
$octopusAPIKey = "API-YOURKEYHERE"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"

# Lifecycle name to search for and replace
$oldLifecycleName = "MyOldLifecycleName"
# New lifecycle to assign (must exist before running script)
$newLifecycleName = "MyNewLifecycleName"

# What-If flag (set to true to test changes without comitting them)
$whatIf = $true

####
## Perform API Calls
####

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object { $_.Name -eq $spaceName }

# Get lifecycles
$allLifecycles = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/lifecycles/all" -Headers $header
$originalLifecycle = $allLifecycles | Where-Object { $_.Name -eq $oldLifecycleName }
$newLifecycle = $allLifecycles | Where-Object { $_.Name -eq $newLifecycleName }

# Get projects for space
$projectList = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header

# Loop through projects
foreach ($project in $projectList) {

    # Set to false and change to identify when changes should be committed
    $changesMade = $false

    if ($project.LifecycleId -eq $($originalLifecycle.Id)) {

        Write-Host -ForegroundColor Yellow "Project $($project.Name) is using deprecated lifecycle $($oldLifecycleName)"

        $project.LifecycleId = $($newLifecycle.Id)

        $changesMade = $true

    }

    if ($changesMade) {

        if ($whatIf) {
            Write-Host -ForegroundColor Green "`tProject would be updated - '$($project.Name)' would be updated to use the lifecycle '$($newLifecycle.Name)'"
        }
        elseif ($project -ne $projectList[-1]) {
            Write-Host "`tLifecycle values updated for $($step.Name) in $($project.Name), checking next project"
        }
        else {
            Write-Host "`tLifecycle values updated for $($step.Name) in $($project.Name)."
        }
    }

    if (!$whatIf -and $changesMade) {
        Write-Host -ForegroundColor Green "`tUpdating project metadata for $($project.Name)"
        Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)" -Headers $header -Body ($project | ConvertTo-Json -Depth 10)
    }
}
