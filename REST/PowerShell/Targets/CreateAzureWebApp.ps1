$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"
$azureServicePrincipalName = "MyAzureAccount"
$azureResourceGroupName = "MyResourceGroup"
$environmentNames = @("Development", "Production")
$roles = @("Myrole")
$environmentIds = @()
$azureWebAppName = "MyAzureWebAppName"

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get Azure account
$azureAccount = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/accounts/all" -Headers $header) | Where-Object {$_.Name -eq $azureServicePrincipalName}

# Get Environments
$environments = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/environments/all" -Headers $header) | Where-Object {$environmentNames -contains $_.Name}
foreach ($environment in $environments)
{
    $environmentIds += $environment.Id
}

# Build json payload
$jsonPayload = @{
    Name = $azureWebAppName
    EndPoint = @{
        CommunicationStyle = "AzureWebApp"
        AccountId = $azureAccount.Id
        ResourceGroupName = $azureResourceGroupName
        WebAppName = $azureWebAppName
    }
    Roles = $roles
    EnvironmentIds = $environmentIds
}

# Register the target to Octopus Deploy
Invoke-RestMethod -Method Post -Uri "$octopusURL/api/$($space.Id)/machines" -Headers $header -Body ($jsonPayload | ConvertTo-Json -Depth 10)