# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll' 

$apikey = 'API-MYAPIKEY' # Get this from your profile
$octopusURI = 'http://MY-OCTOPUS' # Your server address

$triggerEnvironment = "Dev" # Set this to whatever environment should auto deploy
$triggerRole = "Web-server" # Set this to the deployment target role that should auto deploy

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

$environment = $repository.Environments.FindByName($triggerEnvironment)

$triggerFilter = New-Object Octopus.Client.Model.Triggers.MachineFilterResource
$triggerFilter.EnvironmentIds.Add($environment.Id)
$triggerFilter.Roles.Add($triggerEnvironment)
$triggerFilter.EventGroups.Add("MachineAvailableForDeployment")

$triggerAction = New-Object Octopus.Client.Model.Triggers.AutoDeployActionResource
$triggerAction.ShouldRedeployWhenMachineHasBeenDeployedTo = $false

$projects = $repository.Projects.GetAll()

foreach ($project in $projects) {
    $repository.ProjectTriggers.CreateOrModify($project, "Automatically deploy to $triggerRole", $triggerFilter, $triggerAction)
}
