$ErrorActionPreference = "Stop";

# Define working variables

$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-YOURKEY"

$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

# Space name
$spaceName = "Default"

# Optional, filter by Tenant name
$tenantName = ""

# Optional, filter by Project name
$projectName = ""

# Optional, filter by Environment name
$environmentName = ""

# Get Space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get Environments
$environments = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/environments/all" -Headers $header)

# Get Environment
$environmentId = $null
if (-not [string]::IsNullOrWhitespace($environmentName)){
    
    $environment = $environments | Select-Object -First 1
    if($null -ne $environment) {
        Write-Host "Found environment matching name: $($environment.Name) ($($environment.Id))"
        $environmentId = $environment.Id
    }
}

# Get Project
$projectId = $null
if (-not [string]::IsNullOrWhitespace($projectName)){
    $projectSearch = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects?name=$projectName" -Headers $header)
    $project = $projectSearch.Items | Select-Object -First 1
    if($null -ne $project) {
        Write-Host "Found project matching name: $($project.Name) ($($project.Id))"
        $projectId = $project.Id
    }
}

# Get tenant(s)
$tenantsResponse = $null
$tenants = @()
if (-not [string]::IsNullOrWhitespace($tenantName)){
    $tenantsSearch = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/tenants?name=$tenantName" -Headers $header)
    $tenant = $tenantsSearch.Items | Select-Object -First 1
    if($null -ne $tenant) {
        Write-Host "Found tenant matching name: $($tenant.Name) ($($tenant.Id))"
        $tenants += $tenant
    }
} 
else {
    do {
        $uri = if ($tenantsResponse) { $octopusURL + $tenantsResponse.Links.'Page.Next' } else { "$octopusURL/api/$($space.Id)/tenants" }
        $tenantsResponse = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
        $tenants += $tenantsResponse.Items
        
    } while ($tenantsResponse.Links.'Page.Next')
}

# Loop through tenants
foreach ($tenant in $tenants) {
    Write-Host "Working on tenant: $($tenant.Name) ($($tenant.Id))"
    
    # Get tenant variables
    $variables = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/tenants/$($tenant.Id)/variables" -Headers $header)

    # Get project templates
    $projects = $variables.ProjectVariables | Get-Member | Where-Object {$_.MemberType -eq "NoteProperty"} | Select-Object -ExpandProperty "Name"
    
    if($null -ne $projectId){
        Write-Host "Filtering on project: $($project.Name) ($($project.Id))"
        $projects = $projects | Where-Object { $_ -eq $projectId}
    }


    # Loop through projects
    foreach ($projectKey in $projects)
    {
        $project = $variables.ProjectVariables.$projectKey
        $projectName = $project.ProjectName
        if($project.Templates.Count -le 0) {
            continue;
        }
        Write-Host "Working on Project: $($project.ProjectName) ($projectKey)"
        $projectConnectedEnvironments = $project.Variables | Get-Member | Where-Object {$_.MemberType -eq "NoteProperty"} | Select-Object -ExpandProperty "Name"
        
        if($null -ne $environmentId){
            Write-Host "Filtering on project: $($project.Name) ($($project.Id))"
            $projectConnectedEnvironments = $projectConnectedEnvironments | Where-Object { $_ -eq $environmentId}
        }

        foreach($template in $project.Templates) {
            $templateId = $template.Id
            # Loop through each of the connected environments variables
            foreach($envId in $projectConnectedEnvironments) {
                $envName = ($environments | Where-Object {$_.Id -eq $envId} | Select-Object -First 1).Name
                Write-Host "$($template.Name) value for $envName = $($project.Variables.$envId.$templateId)"
            }
        }
        Write-Host ""
    }
}