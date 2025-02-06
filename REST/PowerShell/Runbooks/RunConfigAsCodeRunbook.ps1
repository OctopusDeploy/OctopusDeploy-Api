# This script is for early access Config-as-Code Runbooks. This script may break in subsequent changes.

$ErrorActionPreference = "Stop";

Add-Type -AssemblyName System.Net

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"
$projectName = "MyProject"
$runbookName = "MyRunbook"
$gitRef = "refs/heads/main"
$environmentNames = @("Development", "Staging")
$environmentIds = @()

# Optional Tenant
$tenantName = ""
$tenantId = $null

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName} 

# Get project
$project = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header) | Where-Object {$_.Name -eq $projectName}

# Convert GitRef to safe string
$encodedGitRef = [System.Net.WebUtility]::UrlEncode($gitRef)

# Get runbook
$runbook = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/$($space.Id)/projects/$($project.Id)/$($encodedGitRef)/runbooks" -Headers $header).Items | Where-Object {$_.Name -eq $runbookName}

# Get environments
$environments = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/environments/all" -Headers $header) | Where-Object {$environmentNames -contains $_.Name}
foreach ($environment in $environments)
{
    $environmentIds += $environment.Id
}

# Optionally get tenant
if (![string]::IsNullOrEmpty($tenantName)) {
    $tenant = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/tenants/all" -Headers $header) | Where-Object {$_.Name -eq $tenantName} | Select-Object -First 1
    $tenantId = $tenant.Id
}

foreach ($environmentId in $environmentIds)
{
    # Create json payload
    $jsonPayload = @{
        SelectedPackages = @()
        SelectedGitResources = @()
        Runs = @(@{
            EnvironmentId = $environmentId
            TenantId = $tenantId
            SkipActions = @()
            SpecificMachineIds = @()
            ExcludedMachineIds = @()
        })
    }

    # Run runbook
    Invoke-RestMethod -Method Post -Uri "$octopusURL/api/spaces/$($space.Id)/projects/$($project.Id)/$($encodedGitRef)/runbooks/$($runbook.Slug)/run/v1" -Body ($jsonPayload | ConvertTo-Json -Depth 10) -Headers $header
}
