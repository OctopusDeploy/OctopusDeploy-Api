# You can get this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
# Load octopus.client assembly
Add-Type -Path "c:\octopus.client\Octopus.Client.dll"

$octopusURL = "https://your.octopus.app/api"
$octopusAPIKey = "API-YOURAPIKEY"
$spaceName = "Default"

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURL, $octopusAPIKey
$repository = New-Object Octopus.Client.OctopusRepository $endpoint
$client = New-Object Octopus.Client.OctopusClient $endpoint

try {
    # Get space
    $space = $repository.Spaces.FindByName($spaceName)
    $repositoryForSpace = $client.ForSpace($space)

    # Get Tentacles
    $targets = $repositoryForSpace.Machines.GetAll()
    $workers = $repositoryForSpace.Workers.GetAll()

    ($targets + $workers)
    | Where-Object { $_.Endpoint -and $_.Endpoint.TentacleVersionDetails }
    | ForEach-Object {
        Write-Host "Checking Tentacle version for $($_.Name)"
        $details = $_.Endpoint.TentacleVersionDetails

        Write-Host "`tTentacle status: $($_.HealthStatus)"
        Write-Host "`tCurrent version: $($details.Version)"
        Write-Host "`tUpgrade suggested: $($details.UpgradeSuggested)"
        Write-Host "`tUpgrade required: $($details.UpgradeRequired)"
    }
}
catch {
    Write-Host "There was an error during the request: $($octoError.Message)"
    exit
}