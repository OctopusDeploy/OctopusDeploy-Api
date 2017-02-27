# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll' 

$apikey = 'API-MYAPIKEY' # Get this from your profile
$octopusURI = 'http://MY-OCTOPUS' # Your server address

$projectName = "My project via the api" # Name of the new project
$projectGroupName = "All projects" # Name of the existing project group the new project will be added to
$lifecycleName = "Default Lifecycle" # Name of the existing lifecycle the new project will use


$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

$projectGroup = $repository.ProjectGroups.FindByName($projectGroupName)
$lifecycle = $repository.Lifecycles.FindByName($lifecycleName)

$project = $repository.Projects.CreateOrModify($projectName, $projectGroup, $lifecycle)
$project.Save()
