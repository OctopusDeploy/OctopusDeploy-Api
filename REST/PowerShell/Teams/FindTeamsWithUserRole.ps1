# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"
$userRoleName = "Deployment creator"

try
{
    # Get space
    $space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

    # Get user role
    $userRole = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/userroles/all" -Headers $header) | Where-Object {$_.Name -eq $userRoleName}

    # Get teams collection
    $teams = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/teams/all" -Headers $header
    
    # Loop through teams
    $teamNames = @()
    foreach ($team in $teams)
    {
        # Get scoped roles for team
        $scopedUserRole = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/teams/$($team.Id)/scopeduserroles" -Headers $header).Items | Where-Object {$_.UserRoleId -eq $userRole.Id}

        # Check for null
        if ($null -ne $scopedUserRole)
        {
            # Add to teams
            $teamNames += $team.Name
        }
    }

    # Loop through results
    Write-Host "The following teams are using role $($userRoleName):"
    foreach ($teamName in $teamNames)
    {
        Write-Host "$teamName"
    }
}
catch
{
    Write-Host $_.Exception.Message
}