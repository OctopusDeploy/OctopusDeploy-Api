$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://yourOctopusURL"
$octopusAPIKey = "API-xx"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$projectName = "ProjectName"
$spaceName = "Default"

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get project
$project = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header) | Where-Object {$_.Name -eq $projectName}

$teams = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/teams?spaces=$($space.Id)&includeSystem=false" -Headers $header).Items

$teamIds = @()

foreach ($team in $teams) {
    $teamIds += $team.Id
}

foreach ($teamId in $teamIds) {
    # Get scoped user roles
    $scopedUserRoles = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/teams/$($teamId)/scopeduserroles" -Headers $header).Items | Where-Object {$_.ProjectIds -contains $project.Id}

    # Loop through results and remove project Id
    foreach ($scopedUserRole in $scopedUserRoles)
    {
        # Filter out project
        $scopedUserRole.ProjectIds = @($scopedUserRole.ProjectIds | Where-Object {$_ -notcontains $project.Id})
        
        # Update scoped user role
        Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/scopeduserroles/$($scopedUserRole.Id)" -Body ($scopedUserRole | ConvertTo-Json -Depth 10) -Headers $header
    }
}
