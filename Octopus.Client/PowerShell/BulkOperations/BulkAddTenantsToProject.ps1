# Load assembly
Add-Type -Path 'C:\Octopus.Client\Octopus.Client.dll'

# Declare variables
$octopusUrl = "YOUR URL"
$octopusApiKey = "YOUR API KEY"
$spaceName = "YOUR SPACE NAME"
$projectName = "PROJECT NAME TO ADD"
$environmentNameList =  "ENVIRONMENTS TO TIE TO" # "Development,Test"
$tenantTag = "TENANT TAG TO FILTER ON" #Format = [Tenant Tag Set Name]/[Tenant Tag] "Tenant Type/Customer"
$whatIf = $false # Set to true to test out changes before making them
$maxNumberOfTenants = 1 # The max number of tenants you wish to change in this run
$tenantsUpdated = 0

# Create client object
$endpoint = New-Object Octopus.Client.OctopusServerEndpoint($octopusURL, $octopusAPIKey)
$repository = New-Object Octopus.Client.OctopusRepository($endpoint)
$client = New-Object Octopus.Client.OctopusClient($endpoint)

$space = $repository.Spaces.FindByName($spaceName)
$client = $client.ForSpace($space)

# Get project
$project = $client.Projects.FindByName($projectName)

# Get reference to environments
$environments = @()
foreach ($environmentName in $environmentNameList)
{
    $environment = $client.Environments.FindByName($environmentName)

    if ($null -ne $environment)
    {
        $environments += $environment
    }
    else
    {
        Write-Warning "Environment $environmentName not found!"
    }
}

# Get tenants by tag
$tenants = $client.Tenants.FindAll("", @($tenantTag), 1000)

# Loop through returned tenants
foreach ($tenant in $tenants)
{
    $tenantUpdated = $false
    if (($null -eq $tenant.ProjectEnvironments) -or ($tenant.ProjectEnvironments.Count -eq 0))
    {
        # Add project/environments
        $tenant.ConnectToProjectAndEnvironments($project, $environments)
        $tenantUpdated = $true
    }
    else
    {
        # Get existing project connections
        $projectEnvironments = $tenant.ProjectEnvironments | Where-Object {$_.Keys -eq $project.Id}
        
        # Compare environment list
        $missingEnvironments = @()
        foreach ($environment in $environments)
        {
            if ($projectEnvironments.ContainsValue($environment.Id) -eq $false)
            {
                #$missingEnvironments += $environment.Id
                $tenant.ProjectEnvironments[$project.Id].Add($environment.Id)
                $tenantUpdated = $true
            }
        }
    }

    if ($tenantUpdated)
    {
        if ($whatIf)
        {
            $tenant
        }
        else
        {
            # Update tenenat
            $client.Tenants.Modify($tenant)
        }

        $tenantsUpdated ++
    }
    

    if ($tenantsUpdated -ge $maxNumberOfTenants)
    {
        # We out!
        break
    }
}
