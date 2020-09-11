# You can get this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll'

$apikey = 'API-' # Get this from your profile
$octopusURI = 'https://octopus.url' # Your Octopus Server address

$tenantName = '' #Enter tenant name
$newLogo = '' #URL of file. Example: C:\logo.jpg

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI, $apiKey
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

$tenant = $repository.Tenants.FindByName($tenantName)

$update = $repository.Tenants.CreateOrModify($tenant.Name)
$update.SetLogo($newLogo)
$update.Save()
