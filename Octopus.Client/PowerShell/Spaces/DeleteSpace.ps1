# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'path\to\Octopus.Client.dll'

$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint($octopusURL, $octopusAPIKey)
$repository = New-Object Octopus.Client.OctopusRepository($endpoint)

$spaceName = "New Space"

$space = $repository.Spaces.FindByName($spaceName)

if ($null -eq $space) {
    Write-Host "The space $spaceName does not exist."
    exit
}

try {
    $space.TaskQueueStopped = $true

    $repository.Spaces.Modify($space) | Out-Null
    $repository.Spaces.Delete($space) | Out-Null
} catch {
    Write-Host $_.Exception.Message
}