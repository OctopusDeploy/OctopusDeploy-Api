# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll' 

$apikey = 'API-MYAPIKEY' # Get this from your profile
$octopusURI = 'http://MY-OCTOPUS' # Your server address

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

$pfxFilePath = "D:\somewhere\acme.pfx" # note: other file formats are supported https://octopus.com/docs/deploying-applications/certificates/file-formats  
$pfxBase64 = [Convert]::ToBase64String((Get-Content -Path $pfxFilePath -Encoding Byte)) 
$pfxPassword = "Password!"
$certificateName = "Acme HTTPS" # The display name in Octopus

$certificateResource = New-Object -TypeName "Octopus.Client.Model.CertificateResource" -ArgumentList @($certificateName, $pfxBase64, $pfxPassword) 
$certificateResource = $repository.Certificates.Create($certificateResource);