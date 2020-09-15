
# NOTE: this script will fail if the Tenants feature is not enabled on your Octopus Server

# You can get this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path "path\to\Octopus.Client.dll"

# Octopus variables
$octopusURL = "https://youroctopusurl"
$octopusAPIKey = "API-KEY"
$spaceName = "default"
$tenantName = "MyTenant"
$projectNames = @("MyProject")
$environmentNames = @("Development", "Test")
$tenantTags = @("MyTagSet/Beta", "MyTagSet/Stable") # Format: TagSet/Tag

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURL, $octopusAPIKey
$repository = New-Object Octopus.Client.OctopusRepository $endpoint
$client = New-Object Octopus.Client.OctopusClient $endpoint

try
{
    # Get space
    $space = $repository.Spaces.FindByName($spaceName)
    $repositoryForSpace = $client.ForSpace($space)

    # Get environment ids
    $environments = $repositoryForSpace.Environments.GetAll() | Where-Object {$environmentNames -contains $_.Name}

    # Get projects
    $projects = $repositoryForSpace.Projects.GetAll() | Where-Object {$projectNames -contains $_.Name}
    
    # Create projectenvironments
    $projectEnvironments = New-Object Octopus.Client.Model.ReferenceCollection
    foreach ($environment in $environments)
    {
        $projectEnvironments.Add($environment.Id) | Out-Null
    }

    # Create new tenant resource
    $tenant = New-Object Octopus.Client.Model.TenantResource
    $tenant.Name = $tenantName
    
    # Add tenant tags
    foreach ($tenantTag in $tenantTags)
    {
        $tenant.TenantTags.Add($tenantTag) | Out-Null
    }
    
    # Add project environments
    foreach ($project in $projects)
    {
        $tenant.ProjectEnvironments.Add($project.Id, $projectEnvironments) | Out-Null
    }
    
    # Create the tenant
    $repositoryForSpace.Tenants.Create($tenant)
}
catch
{
    Write-Host $_.Exception.Message
}