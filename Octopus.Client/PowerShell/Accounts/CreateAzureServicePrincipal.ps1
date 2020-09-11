# You can get this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'path\to\Octopus.Client.dll'
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"

# Azure service principle details
$azureSubscriptionNumber = "Subscription-Guid"
$azureTenantId = "Tenant-Guid"
$azureClientId = "Client-Guid"
$azureSecret = "Secret"

# Octopus Account details
$accountName = "Azure Account"
$accountDescription = "My Azure Account"
$accountTenantParticipation = "Untenanted"
$accountTenantTags = @()
$accountTenantIds = @()
$accountEnvironmentIds = @()
$spaceName = "default"


$endpoint = New-Object Octopus.Client.OctopusServerEndpoint($octopusURL, $octopusAPIKey)
$repository = New-Object Octopus.Client.OctopusRepository($endpoint)
$client = New-Object Octopus.Client.OctopusClient($endpoint)

try
{
    # Get space
    $space = $repository.Spaces.FindByName($spaceName)
    $repositoryForSpace = $client.ForSpace($space)

    # Create azure service principal object
    $azureAccount = New-Object Octopus.Client.Model.Accounts.AzureServicePrincipalAccountResource
    $azureAccount.ClientId = $azureClientId
    $azureAccount.TenantId = $azureTenantId
    $azureAccount.Description = $accountDescription
    $azureAccount.Name = $accountName
    $azureAccount.Password = $azureSecret
    $azureAccount.SubscriptionNumber = $azureSubscriptionNumber
    $azureAccount.TenantedDeploymentParticipation = [Octopus.Client.Model.TenantedDeploymentMode]::$accountTenantParticipation
    $azureAccount.TenantTags = New-Object Octopus.Client.Model.ReferenceCollection $accountTenantTags
    $azureAccount.TenantIds = New-Object Octopus.Client.Model.ReferenceCollection $accountTenantIds
    $azureAccount.EnvironmentIds = New-Object Octopus.Client.Model.ReferenceCollection $accountEnvironmentIds

    # Create account
    $repositoryForSpace.Accounts.Create($azureAccount)
}
catch
{
    Write-Host $_.Exception.Message
}