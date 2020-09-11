# You can get this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/

# Load octopus.client assembly
Add-Type -Path "path\to\Octopus.Client.dll"

# Octopus variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$spaceName = "default"

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURL, $octopusAPIKey
$repository = New-Object Octopus.Client.OctopusRepository $endpoint
$client = New-Object Octopus.Client.OctopusClient $endpoint

try
{
    # Get space
    $space = $repository.Spaces.FindByName($spaceName)
    $repositoryForSpace = $client.ForSpace($space)

    # Get tasks
    $queuedDeployments = $repositoryForSpace.Tasks.FindAll() | Where-Object {$_.State -eq "Queued" -and $_.HasBeenPickedUpByProcessor -eq $false -and $_.Name -eq "Deploy"}

    # Loop through results
    foreach ($task in $queuedDeployments)
    {
        $repositoryForSpace.Tasks.Cancel($task)   
    }
}
catch
{
    Write-Host $_.Exception.Message
}