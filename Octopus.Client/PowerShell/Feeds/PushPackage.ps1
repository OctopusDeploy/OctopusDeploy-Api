# Load octopus.client assembly
Add-Type -Path "path\to\Octopus.Client.dll"

# Octopus variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$spaceName = "default"
$packageFile = "path\to\package"

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURL, $octopusAPIKey
$repository = New-Object Octopus.Client.OctopusRepository $endpoint
$client = New-Object Octopus.Client.OctopusClient $endpoint
$fileStream = $null

try
{
    # Get space
    $space = $repository.Spaces.FindByName($spaceName)
    $repositoryForSpace = $client.ForSpace($space)

    # Create new package resource
    $package = New-Object Octopus.Client.Model.PackageResource

    # Create filestream object
    $fileStream = New-Object System.IO.FileStream($packageFile, [System.IO.FileMode]::Open)

    # Push package
    $repositoryForSpace.BuiltInPackageRepository.PushPackage($packageFile, $fileStream)
}
catch
{
    Write-Host $_.Exception.Message
}
finally
{
    if ($null -ne $fileStream)
    {
        $fileStream.Close()
    }
}