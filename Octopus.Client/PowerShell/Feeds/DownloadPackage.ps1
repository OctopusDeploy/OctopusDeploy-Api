# Load octopus.client assembly
Add-Type -Path "path\to\Octopus.Client.dll"

# Octopus variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-YOURAPIKEY"
$spaceName = "Default"
$packageName = "packageName"
$packageVersion = "1.0.0.0"
$outputFolder = "C:\Temp\"

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURL, $octopusAPIKey
$repository = New-Object Octopus.Client.OctopusRepository $endpoint
$client = New-Object Octopus.Client.OctopusClient $endpoint

try
{
    # Get space
    $space = $repository.Spaces.FindByName($spaceName)
    $repositoryForSpace = $client.ForSpace($space)

    # Get package
    $package = $repositoryForSpace = $repositoryForSpace.BuiltInPackageRepository.GetPackage($packageName, $packageVersion)

    # Download Package
    $filePath = [System.IO.Path]::Combine($outputFolder, "$($package.PackageId).$($package.Version)$($package.FileExtension)")
    Invoke-RestMethod -Method Get -Uri "$octopusURL/$($package.Links.Raw)" -Headers $header -OutFile $filePath
    Write-Host "Downloaded file to $filePath"
}
catch
{
    Write-Host $_.Exception.Message
}