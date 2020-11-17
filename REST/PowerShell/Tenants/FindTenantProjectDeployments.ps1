$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-YOURKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

# Space name
$spaceName = "Default"

# Tenant name
$tenantName = "TenantName"

# Environment name to evaluate for deployments
$environmentName = "EnvironmentName"

# Get Space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get Environment
$envSearch = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/environments?name=$environmentName" -Headers $header)
$environment = $envSearch.Items | Select-Object -First 1

# Get Tenant
$tenantsSearch = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/tenants?name=$tenantName" -Headers $header)
$tenant = $tenantsSearch.Items | Select-Object -First 1

# Get connected projects matching $environmentName
$projectIds = $tenant.ProjectEnvironments | Get-Member | Where-Object {$_.MemberType -eq "NoteProperty"} | Select-Object -ExpandProperty "Name" | Where-Object {$tenant.ProjectEnvironments.$_ -icontains $environment.Id}
$summaryItems = @()
$projectDeployments = @()
foreach($projectId in $projectIds)
{
    # Get project
    $project = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/$projectId" -Headers $header)
    
    # Get deployments for project + environment
    $deployments = @()
    $response = $null
    do {
        $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/$($space.Id)/deployments?projects=$($projectId)&tenants=$($tenant.Id)&environments=$($environment.Id)" }
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
        $deployments += $response.Items
    } while ($response.Links.'Page.Next')

    if($deployments.Count -lt 1) {
        Write-Host "No deployments found for '$($project.Name)' ($($projectId)) to $environmentName"
    }
    else {
        # Get last deployment 
        $lastDeployment = $deployments | Sort-Object -Property Created -Descending | Select-Object -First 1
        
        # Get server task
        $lastdeploymentTask = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/tasks/$($lastDeployment.TaskId)" -Headers $header)
        
        # Augment the last deployment with the task status (success/failed/canceled etc)
        $lastDeployment | Add-Member -NotePropertyName DeploymentState -NotePropertyValue $lastdeploymentTask.State
        
        # Create summary
        $summaryItem = [PsCustomObject]@{
            ProjectId = $project.Id
            ProjectName = $project.Name
            ReleaseId = $lastDeployment.ReleaseId
            DeploymentId = $lastDeployment.Id
            TaskId = $lastDeployment.TaskId
            DeploymentState = $lastDeployment.DeploymentState
            WebLink = "$octopusURL$($lastdeploymentTask.Links.Web)"
        }
        $summaryItems += $summaryItem
        
        # Add deployment to another list
        $projectDeployments += $lastDeployment
    }
}

# Summary
$summaryItems | Format-Table

# All details
#$projectDeployments | Format-Table
