# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll' 

$apikey = 'API-MYAPIKEY' # Get this from your profile
$octopusURI = 'http://MY-OCTOPUS' # Your server address

$roles = "web-server", "app-server" # The roles that are transient

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

$projects = $repository.Projects.GetAll()
$projects | % {
    $project = $_
    $project.ProjectConnectivityPolicy.SkipMachineBehavior = [Octopus.Client.Model.SkipMachineBehavior]::SkipUnavailableMachines
    $roles | % { $project.ProjectConnectivityPolicy.TargetRoles.Add($_) }
    $repository.Projects.Modify($project)
}
