$octopusURL = "https://yoururl.com" # Replace with your instance URL
$octopusAPIKey = "YOUR API KEY" # Replace with a service account API Key
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

Write-Host "Pulling all users, teams, and roles"
$userList = Invoke-RestMethod -Method GET -Uri "$OctopusUrl/api/users?skip=0&take=10000" -Headers $header
$teamList = Invoke-RestMethod -Method GET -Uri "$OctopusUrl/api/teams?skip=0&take=10000&includeSystem=true" -Headers $header
$userRoleList = Invoke-RestMethod -Method GET -Uri "$OctopusUrl/api/userroles?skip=0&take=10000" -Headers $header
$spaceList = Invoke-RestMethod -Method GET -Uri "$OctopusUrl/api/spaces?skip=0&take=10000" -Headers $header
$environmentCache = @{}
$projectCache = @{}
$tenantCache = @{}
$projectGroupCache = @{}
Write-Host "All data needed has been pulled."

foreach ($team in $teamList.Items)
{
    Write-Host "Team: $($team.Name)"

    Write-Host "    Users:"
    foreach ($memberId in $team.MemberUserIds)
    {
        $user = $userList.Items | Where-Object {$_.Id -eq $memberId}
        Write-Host "        $($user.DisplayName) $($user.EmailAddress)"
    }

    Write-Host "    External Security Groups:"
    foreach ($externalSecurityGroup in $team.ExternalSecurityGroups)
    {
        Write-Host "        $($externalSecurityGroup.DisplayName)"
    }

    $scopedUserRoles = Invoke-RestMethod -Method GET -Uri "$OctopusUrl/api/teams/$($team.Id)/scopeduserroles?skip=0&take=10000" -Headers $header
    Write-Host "    Roles:"
    foreach ($scopedRole in $scopedUserRoles.Items)
    {       
        $spaceId = $scopedRole.SpaceId 
        $space = $spaceList.Items | Where-Object {$_.Id -eq $spaceId}
        if ($space)
        {
            Write-Host "        Space: $($space.Name)"
        }
        else
        {
            Write-Host "        Space: System"
        }

        $role = $userRoleList.Items | Where-Object {$_.Id -eq $scopedRole.UserRoleId}
        Write-Host "            $($role.Name)"
        if ($scopedRole.EnvironmentIds.Count -eq 0)
        {
            Write-Host "                Environments: All"
        }
        else
        {
            
            if (Get-Member -InputObject $environmentCache -Name $spaceId -MemberType Properties)
            {
                $environmentList = $environmentCache.$spaceId
            }
            else
            {
                $environmentList = Invoke-RestMethod -Method GET -Uri "$OctopusUrl/api/$spaceId/environments?skip=0&take=10000" -Headers $header 
                $environmentCache.$spaceId = $environmentList
            }

            Write-Host "                Environments:"
            foreach ($environmentId in $scopedRole.EnvironmentIds)
            {
                $environment = $environmentList.Items | Where-Object {$_.Id -eq $environmentId}
                Write-Host "                    $($environment.Name)"
            }
        }

        if ($scopedRole.ProjectIds.Count -eq 0)
        {
            Write-Host "                Projects: All"
        }
        else
        {
            
            if (Get-Member -InputObject $projectCache -Name $spaceId -MemberType Properties)
            {
                $projectList = $projectCache.$spaceId
            }
            else
            {
                $projectList = Invoke-RestMethod -Method GET -Uri "$OctopusUrl/api/$spaceId/projects?skip=0&take=10000" -Headers $header 
                $projectCache.$spaceId = $projectList
            }

            Write-Host "                Projects:"
            foreach ($projectId in $scopedRole.ProjectIds)
            {
                $project = $projectList.Items | Where-Object {$_.Id -eq $projectId}
                Write-Host "                    $($project.Name)"
            }
        }

        if ($scopedRole.ProjectGroupIds.Count -eq 0)
        {
            Write-Host "                Projects Groups: All"
        }
        else
        {
            
            if (Get-Member -InputObject $projectGroupCache -Name $spaceId -MemberType Properties)
            {
                $projectGroupList = $projectGroupCache.$spaceId
            }
            else
            {
                $projectGroupList = Invoke-RestMethod -Method GET -Uri "$OctopusUrl/api/$spaceId/projectgroups?skip=0&take=10000" -Headers $header 
                $projectGroupCache.$spaceId = $projectGroupList
            }

            Write-Host "                Project Groups:"
            foreach ($projectGroupId in $scopedRole.ProjectGroupIds)
            {
                $projectGroup = $projectGroupList.Items | Where-Object {$_.Id -eq $projectGroupId}
                Write-Host "                    $($projectGroup.Name)"
            }
        }

        if ($scopedRole.TenantIds.Count -eq 0)
        {
            Write-Host "                Tenants: All"
        }
        else
        {
            
            if (Get-Member -InputObject $tenantCache -Name $spaceId -MemberType Properties)
            {
                $tenantList = $projectGroupCache.$spaceId
            }
            else
            {
                $tenantList = Invoke-RestMethod -Method GET -Uri "$OctopusUrl/api/$spaceId/tenants?skip=0&take=10000" -Headers $header 
                $tenantCache.$spaceId = $tenantList
            }

            Write-Host "                Tenants:"
            foreach ($tenantId in $scopedRole.TenantIds)
            {
                $tenant = $tenantList.Items | Where-Object {$_.Id -eq $tenantId}
                Write-Host "                    $($tenant.Name)"
            }
        }
        
    }
}