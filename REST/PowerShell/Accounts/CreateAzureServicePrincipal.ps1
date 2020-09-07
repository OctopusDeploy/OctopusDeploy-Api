# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"

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

try
{
    # Get space
    $space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}
    
    # Create JSON payload
    $jsonPayload = @{
        AccountType = "AzureServicePrincipal"
        AzureEnvironment = ""
        SubscriptionNumber = $azureSubscriptionNumber
        Password = @{
            HasValue = $true
            NewValue = $azureSecret
        }
        TenantId = $azureTenantId
        ClientId = $azureClientId
        ActiveDirectoryEndpointBaseUri = ""
        ResourceManagementEndpointBaseUri = ""
        Name = $accountName
        Description = $accountDescription
        TenantedDeploymentParticipation = $accountTenantParticipation
        TenantTags = $accountTenantTags
        TenantIds = $accountTenantIds
        EnvironmentIds = $accountEnvironmentIds
    }

    # Add Azure account
    Invoke-RestMethod -Method Post -Uri "$octopusURL/api/$($space.Id)/accounts" -Body ($jsonPayload | ConvertTo-Json -Depth 10) -Headers $header
}
catch
{
    Write-Host $_.Exception.Message
}