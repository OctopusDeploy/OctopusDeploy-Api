# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/

Add-Type -Path 'Octopus.Client.dll' 

$apikey = 'API-MYAPIKEY' # Get this from your profile
$octopusURI = 'http://MY-OCTOPUS' # Your server address

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

$certificateName = "Acme HTTPS"

$currentCertificate = $repository.Certificates.FindByName($certificateName);

$replacementPfxPath = "D:\somewhere\replacement.pfx"
$pfxBase64 = [Convert]::ToBase64String((Get-Content -Path $replacementPfxPath -Encoding Byte)) 
$pfxPassword = "Password!"

$replacementCertificate = $repository.Certificates.Replace($currentCertificate, $pfxBase64, $pfxPassword);