##CONFIG
$OctopusURL = "" #Octopus URL
$OctopusAPIKey = "" #Octopus API Key

$AccountName = "" #Name you want to give to the account.
$ClientId = "" #Your Azure Active Directory Client ID. This is a GUID in the format xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx. This value is known as Client ID in the Azure Portal, and Application ID in the API.
$Password = "" #The password for the Azure Active Directory application. This value is known as Key in the Azure Portal, and Password in the API.
$SubscriptionID = "" #Your Azure subscription ID. This is a GUID in the format xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
$TenantId = "" #Your Azure Active Directory Tenant ID. This is a GUID in the format xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

##PROCESS##
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$body = @{
    AccountType = "AzureServicePrincipal"
    ClientId = $ClientId
    EnvironmentIds = "" #Scoped to all environments
    #EnvironmentIds = @("Environments-1","Environments-21") #Scoped to specific environments
    Name = $AccountName
    Password = @{
                    NewValue = $Password
                }
    SubscriptionNumber = $SubscriptionID
    TenantId= $TenantId
} | ConvertTo-Json

Invoke-WebRequest $OctopusURL/api/accounts -Method Post -Headers $header -Body $body