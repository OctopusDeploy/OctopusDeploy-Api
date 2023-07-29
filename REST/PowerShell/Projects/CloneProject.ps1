$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-KEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"
$sourceProjectName = "Enter Source Project Name here"
$sourceLifecycleToUse = "Enter Lifecycle Name here"
$destinationProjectName = "Enter Destination Project Name here"
$destinationProjectGroupName = "Enter Project Group Name here"
$destinationProjectDescription = "Project clone of $($sourceProjectName)"

# Get space
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -ieq $spaceName }

# Get source project
$sourceProjects = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/projects?partialName=$([uri]::EscapeDataString($sourceProjectName))&skip=0&take=100" -Headers $header 
$matchingSourceProjects = @($sourceProjects.Items | Where-Object { $_.Name -ieq $sourceProjectName }) 
$firstMatchingSourceProject = $matchingSourceProjects | Select-Object -First 1
if ($matchingSourceProjects.Count -gt 1) {
    Write-Warning "Multiple projects found matching name $($sourceProjectName), choosing first one ($($firstMatchingSourceProject.Id))"
}

# Get lifecycle to use
$lifecycles = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/lifecycles?partialName=$([uri]::EscapeDataString($sourceLifecycleToUse))&skip=0&take=100" -Headers $header 
$matchingLifecycles = @($lifecycles.Items | Where-Object { $_.Name -ieq $sourceLifecycleToUse })
$firstMatchingLifecycle = $matchingLifecycles | Select-Object -First 1
if ($matchingLifecycles.Count -gt 1) {
    Write-Warning "Multiple lifecycles found matching name $($sourceLifecycleToUse), choosing first one ($($firstMatchingLifecycle.Id))"
}

# Get project Group
$projectGroups = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/projectgroups?partialName=$([uri]::EscapeDataString($destinationProjectGroupName))&skip=0&take=100" -Headers $header 
$matchingProjectGroups = @($projectGroups.Items | Where-Object { $_.Name -ieq $destinationProjectGroupName }) 
$firstMatchingProjectGroup = $matchingProjectGroups | Select-Object -First 1
if ($matchingProjectGroups.Count -gt 1) {
    Write-Warning "Multiple project groups found matching name $($destinationProjectGroupName), choosing first one ($($firstMatchingProjectGroup.Id))"
}

# Clone project
$clonedProjectRequest = @{
    Name           = $destinationProjectName
    Description    = $destinationProjectDescription
    LifecycleId    = $firstMatchingLifecycle.Id
    ProjectGroupId = $firstMatchingProjectGroup.Id
}

$newProject = Invoke-RestMethod -Method POST -Uri "$octopusURL/api/$($space.Id)/projects?clone=$($firstMatchingSourceProject.Id)" -Headers $header -Body ($clonedProjectRequest | ConvertTo-Json -Depth 10)
$newProject