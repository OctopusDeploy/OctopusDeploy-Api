$OctopusAPIKey = "API-XXXXXXXXXXXXXXXXXXXXXX"
$OctopusUrl = "https://octopus.url"
$SpaceId = "Spaces-22"
$WhatIf = $true

$header = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$header.Add("X-Octopus-ApiKey", $OctopusAPIKey)

$tenantList = Invoke-RestMethod "$OctopusUrl/api/$SpaceId/tenants?skip=0&take=1000000" -Headers $header
$projectList = Invoke-RestMethod "$OctopusUrl/api/$SpaceId/projects?skip=0&take=1000000" -Headers $header

foreach ($tenant in $tenantList.Items)
{
    $tenantModified = $false

    $assignedProjects = $tenant.ProjectEnvironments | Get-Member | where {$_.MemberType -eq "NoteProperty"} | Select-Object -Property "Name"

    foreach ($project in $assignedProjects)
    {
        $projectId = $project.Name
        $filteredProjectList = @($projectList.Items | where {$_.Id -eq $projectId })
        if ($filteredProjectList.Length -gt 0)
        {
            Write-Host "Project $projectId found for tenant $($tenant.Name)"
        }
        else
        {
            Write-Host "Tenant $($tenant.Name) is assigned to the project $projectId which does not exist anymore - removing reference"
            $tenantModified = $true
            $tenant.ProjectEnvironments.PSObject.Properties.Remove($projectId)
        }
    }

    if ($tenantModified -eq $true)
    {
        Write-Host "The tenant $($tenant.Name) was modified, calling the update endpoint"
        $tenantBodyAsJson = $tenant | ConvertTo-Json -Depth 10
        Write-Host "The new tenant body will be:"
        Write-Host $tenantBodyAsJson

        if ($WhatIf -eq $false)
        {
            Write-Host "What if set to false, hitting the API"

            Write-Host "Removing the dead projects from the tenant"
            Invoke-RestMethod "$OctopusUrl/$($tenant.Links.Self)" -Method PUT -Body $tenantBodyAsJson -Headers $header
        }
        else
        {
            Write-Host "What if set to true, skipping API call"
        }
    }
}