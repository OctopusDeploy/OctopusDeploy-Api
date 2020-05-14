$OctopusUrl = "https://your-octopus-url" 
$APIKey = "API-XXXXXXXXXXXXXXXXXXXXXXXXXX"
$servicePrincipalName = "Existing Azure Service Principal Name"
$spaceName = "Default"
$azureResourceGroupName = "Azure resource Group Name"

$path = Join-Path (Get-Item ((Get-Package Octopus.Client).source)).Directory.FullName "lib/net452/Octopus.Client.dll"

Add-Type -Path $path

# Set up endpoint and repository
$endpoint = new-object Octopus.Client.OctopusServerEndpoint $OctopusUrl, $APIKey
$repository = new-object Octopus.Client.OctopusRepository $endpoint

# Find Space
$space = $repository.Spaces.FindByName($spaceName)

$repository = New-Object -TypeName Octopus.Client.OctopusRepository $endpoint, ([Octopus.Client.RepositoryScope]::ForSpace($space))

# Find existing Azure Service Principal to connect the deploymnet target tos
$accountDetails = $repository.Accounts.FindByName($servicePrincipalName)
$accountId = $accountDetails.Id

# Add environments you wish the target to be created in
$environments = @('Dev', 'Test')

foreach ($environment in $environments) {

    $environmentDetails = $repository.Environments.FindByName($environment)
    $environmentId = $environmentDetails.Id
    $environmentToLower = $environment.ToLowerInvariant()

    #===================== TARGET DETAILS

    $webAppName = "webapp - $environmentToLower"
    $webTarget = new-object Octopus.Client.Model.MachineResource -Property @{
                        Name = $webAppName

                        # Choose your roles
                        Roles = new-object Octopus.Client.Model.ReferenceCollection("webapp")

                        Endpoint = new-object Octopus.Client.Model.Endpoints.AzureWebAppEndpointResource -Property @{
                            
                            # choose your service principal associated with your webapp target.
                            AccountId = $accountId 

                            # Choose the appropriate azure resource group name
                            ResourceGroupName = $azureResourceGroupName

                            # Your WebApp Name specific to Azure.
                            WebAppName = "web-$environmentToLower" }
                        EnvironmentIds = new-object Octopus.Client.Model.ReferenceCollection($environmentId)
                    };

    Write-Host "creating target in Octopus for $webAppName in Environment $environment"
    
    # Create your target
    $repository.Machines.Create($webTarget, $null);

    #===================== END TARGET DETAILS

    # Adding more targets below per environment as required.
}
