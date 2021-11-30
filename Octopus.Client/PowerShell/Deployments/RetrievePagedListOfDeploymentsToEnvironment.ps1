# Load octopus.client assembly
Add-Type -Path "Octopus.Client.dll"
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-KEY"

$spaceName = "Default"
$environmentName = "Development"

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURL, $octopusAPIKey
$repository = New-Object Octopus.Client.OctopusRepository $endpoint


# Get space id
$space = $repository.Spaces.FindByName($spaceName)
Write-Host "Using Space named $($space.Name) with id $($space.Id)"

# Create space specific repository
$repositoryForSpace = [Octopus.Client.OctopusRepositoryExtensions]::ForSpace($repository, $space)

# Get environment
$environment = $repositoryForSpace.Environments.FindByName($environmentName)

# Get deployments to environment
$projects = @()
$environments = @($environment.Id)
$deployments = New-Object System.Collections.Generic.List[System.Object] 
    
$repositoryForSpace.Deployments.Paginate($projects, $environments, {param($page) 
    Write-Host "Found $($page.Items.Count) deployments.";
    $deployments.AddRange($page.Items); 
    return $True; 
})

Write-Host "Retrieved $($deployments.Count) deployments to environment $($environmentName)"
