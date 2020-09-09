# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"
$teamName = "MyTeam"
$userRoleName = "Deployment creator"
$environmentNames = @("Development", "Staging")
$environmentIds = @()

try
{
    # Get space
    $space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

    # Get team
    $team = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/teams/all" -Headers $header) | Where-Object {$_.Name -eq $teamName}

    # Get user role
    $userRole = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/userroles/all" -Headers $header) | Where-Object {$_.Name -eq $userRoleName}
    
    # Get scoped user role reference
    $scopedUserRole = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/teams/$($team.Id)/scopeduserroles" -Headers $header).Items | Where-Object {$_.UserRoleId -eq $userRole.Id}

    # Get Environments
    $environments = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/environments/all" -Headers $header) | Where-Object {$environmentNames -contains $_.Name}
    foreach ($environment in $environments)
    {
        $environmentIds += $environment.Id
    }

    # Update the scopedUserRole
    $scopedUserRole.EnvironmentIds += $environmentIds
    
    Invoke-RestMethod -Method Put -Uri "$octopusURL/api/scopeduserroles/$($scopedUserRole.Id)" -Headers $header -Body ($scopedUserRole | ConvertTo-Json -Depth 10)
}
catch
{
    Write-Host $_.Exception.Message
}