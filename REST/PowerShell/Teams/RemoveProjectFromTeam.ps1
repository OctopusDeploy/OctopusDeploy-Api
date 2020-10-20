$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$projectName = "MyProject"
$spaceName = "default"
$teamName = "MyTeam"

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get project
$project = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header) | Where-Object {$_.Name -eq $projectName}

# Get team
$team = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/teams" -Headers $header).Items | Where-Object {$_.Name -eq $teamName}

# Get scoped user roles
$scopedUserRoles = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/teams/$($team.Id)/scopeduserroles" -Headers $header).Items | Where-Object {$_.ProjectIds -contains $project.Id}

# Loop through results and remove project Id
foreach ($scopedUserRole in $scopedUserRoles)
{
    # Filter out project
    $scopedUserRole.ProjectIds = ,($scopedUserRole.ProjectIds | Where-Object {$_ -notcontains $project.Id}) # Yes, the , is supposed to be there
    
    # Update scoped user role
    Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/scopeduserroles/$($scopedUserRole.Id)" -Body ($scopedUserRole | ConvertTo-Json -Depth 10) -Headers $header
}