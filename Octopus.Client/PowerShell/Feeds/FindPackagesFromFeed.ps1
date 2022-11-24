# Load octopus.client assembly
# You can get this dll from NuGet
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path "path\to\Octopus.Client.dll"

# Working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-KEY"
$spaceName = "Default"
$feedName = "Octopus Server (built-in)"
$packageId = "Your-PackageId"

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURL, $octopusAPIKey
$repository = New-Object Octopus.Client.OctopusRepository $endpoint
$client = New-Object Octopus.Client.OctopusClient $endpoint

try
{
    # Get space id
    $space = $repository.Spaces.FindByName($spaceName)
    Write-Host "Using Space named $($space.Name) with id $($space.Id)"

    # Create space specific repository
    $repositoryForSpace = $client.ForSpace($space)
    
    # Get feed
    $feed = $repositoryForSpace.Feeds.FindByName($feedName)
    [string]$path = $feed.Links["SearchPackageVersionsTemplate"]
    
    # Make Generic List method
    $method = $client.GetType().GetMethod("List").MakeGenericMethod([Octopus.Client.Model.PackageResource])
    
    # Set path parameters for call
    $pathParameters = New-Object 'System.Collections.Generic.Dictionary[String,Object]'
    $pathParameters.Add("PackageId",$packageId)
        
    # Set generic method parameters
    [Object[]] $parameters = $path, $pathParameters
    
    # Invoke the List method
    $results = $method.Invoke($client, $parameters)
    
    # Print results
    $results
}
catch
{
    Write-Host $_.Exception.Message
}