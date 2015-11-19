# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll' 

$apikey = 'API-RKXKTNS8D7SDADKUUA0OHTMFSW' # Get this from your profile
$octopusURI = 'http://localhost' # Your server address

$projectId = "projects-1"

$endpoint = new-object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = new-object Octopus.Client.OctopusRepository $endpoint

$releases = $repository.Releases.FindMany({param($r) $r.ProjectId -eq $projectId})

foreach ($release in $releases)
{
    $repository.Releases.Delete($release)
}
