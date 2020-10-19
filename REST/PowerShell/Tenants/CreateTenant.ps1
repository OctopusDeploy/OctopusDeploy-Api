# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
# Provide the space name
$spaceName = "Default"
# Provide a tenant name
$tenantName = "MyTenant"
# Provide project names which have multi-tenancy enabled in their settings.
$projectNames = @("MyProject")
# provide the environments to connect to the projects.
$environmentNames = @("Development", "Test")
# Optionally, provide existing tenant tagsets you wish to apply.
$tenantTags = @("MyTagSet/Beta", "MyTagSet/Stable") # Format: TagSet/Tag

try
{
    # Get space
    $space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

    # Get projects
    $projectIds = @()
    foreach ($projectName in $projectNames)
    {
        $projectIds += ((Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header) | Where-Object {$_.Name -eq $projectName}).Id
    }

    # Get Environments
    $environmentIds = @()
    $environments = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/environments/all" -Headers $header) | Where-Object {$environmentNames -contains $_.Name}
    foreach ($environment in $environments)
    {
        $environmentIds += $environment.Id
    }

    # Build project/environments
    $projectEnvironments = @{}
    foreach ($projectId in $projectIds)
    {
        $projectEnvironments.Add($projectId, $environmentIds)
    }

    # Build json payload
    $jsonPayload = @{
        Name = $tenantName
        TenantTags = $tenantTags
        SpaceId = $space.Id
        ProjectEnvironments = $projectEnvironments
    }

    # Create tenant
    Invoke-RestMethod -Method Post -Uri "$octopusURL/api/$($space.Id)/tenants" -Body ($jsonPayload | ConvertTo-Json -Depth 10) -Headers $header
}
catch
{
    Write-Host $_.Exception.Message
}