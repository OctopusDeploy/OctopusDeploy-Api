$octopusServerUrl = "http://yourserver"
$octopusApiKey = "API-zzzzzzzzzzzzzzzzzzzzzzzz"
$azureSubscription = "zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz"

$envName = "AzureDemo"
$spName = "My Service Principal"

$roleName = "CloudWebServer"

#=========================================================================================================

add-type -path 'C:\tools\Octopus.Client.dll'

$endpoint = new-object Octopus.Client.OctopusServerEndpoint $octopusServerUrl, $octopusApiKey
$repository = new-object Octopus.Client.OctopusRepository $endpoint

$environmentDetails = $repository.Environments.FindByName($envName)
$environmentId = $environmentDetails.Id
Write-Host "got Octopus env " $environmentDetails.Name

$accountDetails = $repository.Accounts.FindByName($spName)
$accountId = $accountDetails.Id
Write-Host "got Octopus account " $accountDetails.Name


Login-AzureRmAccount
Select-AzureRmSubscription $azureSubscription

Write-Host "connected to Azure..."

$webApps = Get-AzureRmWebApp

foreach ($webApp in $webApps)
{
    Write-Host "target for " $webApp.SiteName

    $target = new-object Octopus.Client.Model.MachineResource -Property @{
                        Name = $webApp.SiteName
                        Roles = new-object Octopus.Client.Model.ReferenceCollection($roleName)
                        Endpoint = new-object Octopus.Client.Model.Endpoints.AzureWebAppEndpointResource -Property @{
                            AccountId = $accountId 
                            ResourceGroupName = $webApp.ResourceGroup
                            WebAppName = $webApp.SiteName }
                        EnvironmentIds = new-object Octopus.Client.Model.ReferenceCollection($environmentId)
                    };

    Write-Host "creating target in Octopus for " $webApp.SiteName

    $repository.Machines.Create($target, $null);
}
