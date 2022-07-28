# You can get this dll from NuGet
# https://www.nuget.org/packages/Octopus.Client/
# Load Octopus Client assembly
Add-Type -Path 'path\to\Octopus.Client.dll' 

# Declare working variables
$apikey = 'API-YOURAPIKEY' # Get this from your profile
$octopusURI = 'https://youroctourl' # Your server address
$spaceName = 'default'

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = New-Object Octopus.Client.OctopusRepository $endpoint
$client = New-Object Octopus.Client.OctopusClient $endpoint

try
{
    # Get space
    $space = $repository.Spaces.FindByName($spaceName)
    $repositoryForSpace = $client.ForSpace($space)
    
    # Fill in certificate details
    $pfxFilePath = "path\to\pfxfile.pfx" # note: other file formats are supported https://octopus.com/docs/deploying-applications/certificates/file-formats  
    $pfxBase64 = [Convert]::ToBase64String((Get-Content -Path $pfxFilePath -Encoding Byte)) 
    $pfxPassword = "PFX-file-password"
    $certificateName = "MyCertificate" # The display name in Octopus

    # Create certificate
    $certificateResource = New-Object -TypeName "Octopus.Client.Model.CertificateResource" -ArgumentList @($certificateName, $pfxBase64, $pfxPassword) 
    $certificateResource = $repositoryForSpace.Certificates.Create($certificateResource);
}
catch
{
    Write-Host $_.Exception.Message
}